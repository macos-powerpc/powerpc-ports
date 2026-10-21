# -*- coding: utf-8; mode: python; indent-tabs-mode: nil; tab-width: 4 -*-
"""cargo and rustc stand-ins of the mrustc PortGroup.

On powerpc there is no cargo or rustc; minicargo builds the crates with mrustc.
Python build backends drive cargo themselves:

- setuptools-rust (which also builds maturin itself) runs `rustc -V`, `-Vv`,
  `--print cfg`, `cargo metadata` (only `resolve.root` is used), then
  `cargo build --message-format=json-render-diagnostics` for binaries or
  `cargo rustc --lib --crate-type cdylib -- -C link-arg=...` for extension
  modules, and installs the files named by the "compiler-artifact" messages.
- maturin runs `rustc -vV`, `rustc --print deployment-target`, `cargo metadata`
  (the whole resolved graph: it looks for pyo3/pyo3-ffi/uniffi and their
  versions, features and `[package.metadata]`), then `cargo rustc --lib
  --crate-type cdylib ... -- -C link-args=-Wl,-install_name,...` with
  `-C link-arg=-undefined -C link-arg=dynamic_lookup` in CARGO_ENCODED_RUSTFLAGS.

This script answers those calls:

- `cargo metadata`: the packages and features minicargo resolves
  (`minicargo --emit-graph`), each described from its Cargo.toml. Vendored
  crates get crates.io ids, the others `path+file` ones. The workspace is
  reported as the root package alone (so maturin needs no `cargo tree`).
- `cargo build` / `cargo rustc`: minicargo, then the messages for the binaries
  and the cdylib it made (a `staticlib` is just left in the target directory,
  for makefiles: newsboat links `target/<triple>/release/libnewsboat.a`).
  `--package` picks a member of the workspace. A cdylib is built with `--panic unwind` (rustc's
  default; pyo3 turns panics into Python exceptions), MRUSTC_SHIM_PANIC
  overrides it. Linker arguments from `-C link-arg(s)` (after `--`, or in
  RUSTFLAGS/CARGO_ENCODED_RUSTFLAGS) go to minicargo's `--link-arg`;
  `--remap-path-prefix` (the PortGroup's rust.remap, which maturin passes on
  from cargo.home/config.toml) is dropped.
- `cargo update` / `cargo generate-lockfile` (a Portfile's own `pre-build { system "cargo update" }`, as in
  py-pydantic_core, to make the sdist's Cargo.lock match cargo.crates): nothing to do, minicargo doesn't read
  Cargo.lock but resolves from the vendored crates, i.e. cargo.crates.
- `rustc`: version and `--print` queries; anything else goes to mrustc.

Not supported, exit status 101 with a message: other rustc flags, Rust
`dylib` targets, cross-compiling, other cargo commands.

The mrustc PortGroup writes `cargo` and `rustc` wrappers into
${cargo.home}/bin that set these variables and run this script with the
interpreter of the python PortGroup:

    MRUSTC_SHIM_MINICARGO   minicargo
    MRUSTC_SHIM_MRUSTC      mrustc
    MRUSTC_SHIM_LIBDIR      the installed standard library (minicargo -L)
    MRUSTC_SHIM_VENDOR_DIR  the vendored crates (minicargo --vendor-dir)
    MRUSTC_SHIM_JOBS        minicargo -j
    MRUSTC_SHIM_HOST        the host target triple (also the only target)
    MRUSTC_SHIM_DEPLOYMENT_TARGET  the port's macOS deployment target (maturin asks
                            `rustc --print deployment-target` without MACOSX_DEPLOYMENT_TARGET)
    MRUSTC_TARGET_VER       the Rust version mrustc implements
"""

import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib

TOOL = "cargo"


def die(msg):
    sys.stderr.write(f"{TOOL} (mrustc PortGroup stand-in): {msg}\n")
    sys.exit(101)


def env(name):
    value = os.environ.get(name)
    if not value:
        die(f"{name} is not set (the wrapper in cargo.home/bin sets it)")
    return value


def load_toml(path):
    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError) as e:
        die(f"cannot read {path}: {e}")


# ---------------------------------------------------------------------------
# rustc
# ---------------------------------------------------------------------------

def mrustc_version_line():
    # mrustc answers `--version` like rustc: "rustc 1.90.100 (mrustc v0.12.0 ...)"
    try:
        out = subprocess.run([env("MRUSTC_SHIM_MRUSTC"), "--version"],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             text=True, check=True).stdout
        line = out.splitlines()[0]
        if line.startswith("rustc "):
            return line
    except (OSError, subprocess.CalledProcessError, IndexError):
        pass
    return f"rustc {os.environ.get('MRUSTC_TARGET_VER', '1.90')}.0 (mrustc)"


def print_cfg(target):
    # `mrustc -Z print-cfgs` prints ">name=value" and ">name" lines
    argv = [env("MRUSTC_SHIM_MRUSTC")]
    if target:
        argv += ["--target", target]
    argv += ["-Z", "print-cfgs"]
    try:
        out = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                             text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        die(f"{' '.join(argv)} failed: {e}")
    cfgs = []
    for line in out.splitlines():
        if line.startswith(">"):
            name, eq, value = line[1:].partition("=")
            cfgs.append((name, value if eq else None))
    # mrustc also sets some names to "" next to their real value (target_vendor)
    has_value = {name for name, value in cfgs if value}
    seen = set()
    for name, value in cfgs:
        if (value == "" and name in has_value) or (name, value) in seen:
            continue
        seen.add((name, value))
        print(name if value is None else f'{name}="{value}"')


def rustc_main(args):
    version_flags = {"-V", "--version", "-vV", "-Vv"}
    verbose_flags = {"-v", "--verbose", "-vV", "-Vv"}
    if args and set(args) <= version_flags | verbose_flags and set(args) & version_flags:
        line = mrustc_version_line()
        print(line)
        if set(args) & verbose_flags:
            release = line.split()[1]
            print("binary: rustc")
            print("commit-hash: unknown")
            print("commit-date: unknown")
            print(f"host: {env('MRUSTC_SHIM_HOST')}")
            print(f"release: {release}")
        return

    prints = []
    target = None
    i = 0
    while i < len(args):
        a = args[i]
        i += 1
        if a in ("--print", "--target") and i < len(args):
            value = args[i]
            i += 1
        elif a.startswith(("--print=", "--target=")):
            a, _, value = a.partition("=")
        else:
            continue
        if a == "--print":
            prints.append(value)
        else:
            target = value

    libdir = Path(env("MRUSTC_SHIM_LIBDIR"))
    if not prints:
        # a compilation: what minicargo hands build scripts as RUSTC
        mrustc = env("MRUSTC_SHIM_MRUSTC")
        os.environ.setdefault("MRUSTC_LIBDIR", str(libdir))
        os.execv(mrustc, [mrustc] + args)

    for what in prints:
        if what == "cfg":
            print_cfg(target)
        elif what == "target-list":
            print(env("MRUSTC_SHIM_HOST"))
        elif what == "sysroot":
            print(libdir.parent)
        elif what == "target-libdir":
            print(libdir)
        elif what == "deployment-target":
            print(f"deployment_target={env('MRUSTC_SHIM_DEPLOYMENT_TARGET')}")
        else:
            die(f"rustc --print {what} is not supported")


# ---------------------------------------------------------------------------
# cargo: options
# ---------------------------------------------------------------------------

# options that take a value, as `--name value` or `--name=value`
VALUE_OPTIONS = {
    "--manifest-path", "--features", "-F", "--target", "--target-dir",
    "--message-format", "--profile", "--package", "-p", "--bin", "--jobs", "-j",
    "--crate-type", "--color", "--format-version", "--filter-platform", "--config",
}
# flags without effect here: minicargo has one (optimised) profile, never
# goes online and always uses the vendored crates of Cargo.lock
IGNORED_FLAGS = {
    "--release", "-r", "--locked", "--frozen", "--offline", "-q", "--quiet",
    "-v", "-vv", "--verbose", "--no-deps", "--bins", "--keep-going",
    "--ignore-rust-version", "--future-incompat-report", "--timings",
}
FLAGS = {"--no-default-features", "--all-features", "--lib"}

CRATES_IO = "registry+https://github.com/rust-lang/crates.io-index"


class Options:
    def __init__(self):
        self.values = {}            # option -> list of values
        self.flags = set()
        self.rustc_args = []        # after `--` (cargo rustc)

    def get(self, *names):
        for name in names:
            if name in self.values:
                return self.values[name][-1]
        return None

    def all(self, *names):
        return [v for name in names for v in self.values.get(name, [])]


def parse_options(args):
    opts = Options()
    i = 0
    while i < len(args):
        a = args[i]
        i += 1
        if a == "--":
            opts.rustc_args = args[i:]
            break
        name, eq, value = a.partition("=") if a.startswith("--") else (a, "", "")
        if name in VALUE_OPTIONS:
            if not eq:
                if i == len(args):
                    die(f"{name} takes a value")
                value = args[i]
                i += 1
            opts.values.setdefault(name, []).append(value)
        elif len(a) > 2 and a[:2] in ("-j", "-p", "-F"):
            opts.values.setdefault(a[:2], []).append(a[2:])
        elif a in IGNORED_FLAGS or a in FLAGS:
            opts.flags.add(a)
        else:
            die(f"unsupported option {a!r}")
    return opts


def requested_features(opts, manifest):
    features = []
    for value in opts.all("--features", "-F"):
        features += [f for f in value.replace(",", " ").split() if f]
    if "--all-features" in opts.flags:
        features += list(manifest.get("features", {}))
    return list(dict.fromkeys(features))


def feature_args(opts, pkg):
    args = []
    if "--no-default-features" in opts.flags:
        args.append("--no-default-features")
    features = requested_features(opts, pkg.manifest)
    if features:
        args += ["--features", ",".join(features)]
    return args


def check_platforms(platforms):
    host = env("MRUSTC_SHIM_HOST")
    for t in platforms:
        if t and t != host:
            die(f"cross-compiling to {t} is not supported (host and target are {host})")


def rustc_link_args(flags, where):
    """Linker arguments in rustc flags: `-C link-arg=X`, `-C link-args=X Y`. `-C strip`, `-C split-debuginfo` and
    `-C debuginfo` don't apply to mrustc's output, `--remap-path-prefix` is dropped; anything else is an error."""
    link_args = []
    i = 0
    while i < len(flags):
        f = flags[i]
        i += 1
        # The PortGroup's rust.remap, in rust.flags: maturin passes on the `build.rustflags` of
        # cargo.home/config.toml. mrustc has no such option, and minicargo doesn't read rust.flags
        # in other ports' builds either.
        if f == "--remap-path-prefix":
            i += 1
            continue
        if f.startswith("--remap-path-prefix="):
            continue
        if f == "-C" and i < len(flags):
            opt = flags[i]
            i += 1
        elif f.startswith("-C") and len(f) > 2:
            opt = f[2:]
        else:
            die(f"unsupported rustc flag in {where}: {f}")
        name, _, value = opt.partition("=")
        if name == "link-arg":
            link_args.append(value)
        elif name == "link-args":
            link_args += value.split()
        elif name in ("strip", "split-debuginfo", "debuginfo"):
            sys.stderr.write(f"{TOOL} (mrustc PortGroup stand-in): ignoring -C {opt} ({where})\n")
        else:
            die(f"unsupported rustc flag in {where}: -C {opt}")
    return link_args


def env_rustflags():
    encoded = os.environ.get("CARGO_ENCODED_RUSTFLAGS")
    if encoded is not None:
        return [f for f in encoded.split("\x1f") if f], "CARGO_ENCODED_RUSTFLAGS"
    return os.environ.get("RUSTFLAGS", "").split(), "RUSTFLAGS"


def run_minicargo(argv):
    sys.stderr.write(f"{TOOL} (mrustc PortGroup stand-in): {' '.join(shlex.quote(a) for a in argv)}\n")
    sys.stderr.flush()
    # minicargo's output goes to the log: our stdout is for cargo's output (JSON)
    return subprocess.run(argv, stdout=sys.stderr.fileno()).returncode


# ---------------------------------------------------------------------------
# cargo: packages
# ---------------------------------------------------------------------------

class Package:
    def __init__(self, manifest_path, source=None):
        self.manifest_path = Path(manifest_path).resolve()
        self.dir = self.manifest_path.parent
        self.manifest = load_toml(self.manifest_path)
        self.ws_root, ws_manifest = self.find_workspace()
        self.ws = (ws_manifest or {}).get("workspace", {})
        self.ws_package = self.ws.get("package", {})
        pkg = self.manifest.get("package")
        if pkg is None:
            self.name = None    # virtual manifest
            return
        self.pkg = pkg
        self.name = pkg["name"]
        self.version = str(self.field("version", "0.0.0"))
        self.edition = str(self.field("edition", "2015"))
        self.source = source
        if source:
            self.id = f"{source}#{self.name}@{self.version}"
        else:
            self.id = f"path+file://{self.dir}#{self.name}@{self.version}"

    def find_workspace(self):
        if "workspace" in self.manifest:
            return self.dir, self.manifest
        explicit = self.manifest.get("package", {}).get("workspace")
        if explicit:
            d = (self.dir / explicit).resolve()
            return d, load_toml(d / "Cargo.toml")
        for d in self.dir.parents:
            f = d / "Cargo.toml"
            if f.is_file():
                m = load_toml(f)
                if "workspace" in m:
                    return d, m
        return self.dir, None

    def workspace_member(self, name):
        """The workspace member package called `name` (`cargo build -p name` at the workspace root)"""
        excluded = {(self.ws_root / e).resolve() for e in self.ws.get("exclude", [])}
        dirs = [self.ws_root] + [d for pattern in self.ws.get("members", [])
                                 for d in sorted(self.ws_root.glob(pattern))]
        for d in dirs:
            d = d.resolve()
            if d in excluded or not (d / "Cargo.toml").is_file():
                continue
            if d == self.dir:
                member = self
            else:
                member = Package(d / "Cargo.toml")
            if member.name == name:
                return member
        return None

    def field(self, key, default=None):
        value = self.pkg.get(key, default)
        if isinstance(value, dict) and value.get("workspace"):
            value = self.ws_package.get(key, default)
        return value

    def target_dir(self, opts):
        d = opts.get("--target-dir") or os.environ.get("CARGO_TARGET_DIR")
        return Path(d).resolve() if d else self.ws_root / "target"

    def lib_target(self):
        lib = self.manifest.get("lib")
        if lib is None and not (self.dir / "src" / "lib.rs").is_file():
            return None
        lib = lib or {}
        if lib.get("proc-macro") or lib.get("proc_macro"):
            crate_types = ["proc-macro"]
        else:
            crate_types = lib.get("crate-type", lib.get("crate_type", ["lib"]))
        return self.target(lib.get("name", self.name.replace("-", "_")), crate_types, crate_types,
                           lib.get("path", "src/lib.rs"), lib.get("edition"))

    def bin_targets(self):
        bins = {}
        for b in self.manifest.get("bin", []):
            name = b["name"]
            path = b.get("path")
            if path is None:
                for candidate in (f"src/bin/{name}.rs", f"src/bin/{name}/main.rs"):
                    if (self.dir / candidate).is_file():
                        path = candidate
                        break
                else:
                    path = "src/main.rs"
            bins[name] = (path, b.get("edition"), b.get("required-features", []))
        autobins = self.pkg.get("autobins", not (self.edition == "2015" and bins))
        if autobins:
            used = {str((self.dir / p).resolve()) for p, _, _ in bins.values()}
            found = []
            if (self.dir / "src" / "main.rs").is_file():
                found.append((self.name, "src/main.rs"))
            bindir = self.dir / "src" / "bin"
            if bindir.is_dir():
                for e in sorted(bindir.iterdir()):
                    if e.suffix == ".rs" and e.is_file():
                        found.append((e.stem, f"src/bin/{e.name}"))
                    elif (e / "main.rs").is_file():
                        found.append((e.name, f"src/bin/{e.name}/main.rs"))
            for name, path in found:
                if name not in bins and str((self.dir / path).resolve()) not in used:
                    bins[name] = (path, None, [])
        return [dict(self.target(name, ["bin"], ["bin"], path, edition), **{"required-features": req})
                for name, (path, edition, req) in bins.items()]

    def target(self, name, kind, crate_types, path, edition):
        return {
            "kind": kind,
            "crate_types": crate_types,
            "name": name,
            "src_path": str(self.dir / path),
            "edition": str(edition or self.edition),
            "doc": True,
            "doctest": kind == ["lib"],
            "test": True,
        }

    def targets(self):
        lib = self.lib_target()
        return ([lib] if lib else []) + self.bin_targets()

    def dependencies(self):
        deps = []

        def add(table, kind, target):
            for name, spec in table.items():
                if isinstance(spec, str):
                    spec = {"version": spec}
                if spec.get("workspace"):
                    base = self.ws_package_deps().get(name, {})
                    if isinstance(base, str):
                        base = {"version": base}
                    spec = dict(base, **{k: v for k, v in spec.items() if k != "workspace"})
                    spec["features"] = base.get("features", []) + spec.get("features", [])
                dep = {
                    "name": spec.get("package", name),
                    "source": None if "path" in spec else CRATES_IO,
                    "req": spec.get("version", "*"),
                    "kind": kind,
                    "rename": name if "package" in spec else None,
                    "optional": bool(spec.get("optional", False)),
                    "uses_default_features": spec.get("default-features", spec.get("default_features", True)),
                    "features": spec.get("features", []),
                    "target": target,
                    "registry": None,
                }
                if "path" in spec:
                    dep["path"] = str((self.dir / spec["path"]).resolve())
                deps.append(dep)

        for section, kind in (("dependencies", None), ("dev-dependencies", "dev"), ("build-dependencies", "build")):
            add(self.manifest.get(section, {}), kind, None)
            for cfg, table in self.manifest.get("target", {}).items():
                add(table.get(section, {}), kind, cfg)
        return deps

    def ws_package_deps(self):
        ws = load_toml(self.ws_root / "Cargo.toml") if self.ws_root != self.dir else self.manifest
        return ws.get("workspace", {}).get("dependencies", {})

    def metadata(self):
        def text(v):
            return v if isinstance(v, str) else None
        publish = self.field("publish")
        if publish is False:
            publish = []                # cargo's `publish = false`
        elif not isinstance(publish, list):
            publish = None
        targets = [{k: v for k, v in t.items() if k != "required-features"} for t in self.targets()]
        return {
            "name": self.name,
            "version": self.version,
            "id": self.id,
            "license": text(self.field("license")),
            "license_file": text(self.field("license-file")),
            "description": text(self.field("description")),
            "source": self.source,
            "dependencies": self.dependencies(),
            "targets": targets,
            "features": self.manifest.get("features", {}),
            "manifest_path": str(self.manifest_path),
            "metadata": self.pkg.get("metadata"),
            "publish": publish,
            "authors": self.field("authors", []),
            "categories": self.field("categories", []),
            "keywords": self.field("keywords", []),
            "readme": text(self.field("readme")),
            "repository": text(self.field("repository")),
            "homepage": text(self.field("homepage")),
            "documentation": text(self.field("documentation")),
            "edition": self.edition,
            "links": text(self.pkg.get("links")),
            "default_run": text(self.pkg.get("default-run")),
            "rust_version": text(self.field("rust-version")),
        }


def find_manifest(opts):
    path = opts.get("--manifest-path")
    if path:
        return path
    for d in [Path.cwd()] + list(Path.cwd().parents):
        if (d / "Cargo.toml").is_file():
            return d / "Cargo.toml"
    die("could not find Cargo.toml in the current directory or any parent")


def minicargo_graph(pkg, opts):
    """The packages, features and dependency edges minicargo resolves for this build (`--emit-graph`)"""
    fd, path = tempfile.mkstemp(prefix="minicargo-graph-", suffix=".json")
    os.close(fd)
    try:
        argv = [env("MRUSTC_SHIM_MINICARGO"), str(pkg.dir), "--vendor-dir", env("MRUSTC_SHIM_VENDOR_DIR"),
                "--emit-graph", path] + feature_args(opts, pkg)
        if run_minicargo(argv) != 0:
            die("minicargo could not resolve the packages (see above)")
        with open(path) as f:
            return json.load(f)
    finally:
        os.unlink(path)


# ---------------------------------------------------------------------------
# cargo: commands
# ---------------------------------------------------------------------------

def cargo_metadata(opts):
    fmt = opts.get("--format-version")
    if fmt not in (None, "1"):
        die(f"--format-version {fmt} is not supported")
    check_platforms(opts.all("--filter-platform"))
    root = Package(find_manifest(opts))
    doc = {
        "packages": [],
        "workspace_members": [],
        "workspace_default_members": [],
        "resolve": {"nodes": [], "root": None},
        "target_directory": str(root.target_dir(opts)),
        "version": 1,
        "workspace_root": str(root.ws_root),
        "metadata": None,
    }
    if root.name is not None:
        doc["workspace_members"] = [root.id]
        doc["workspace_default_members"] = [root.id]
        if "--no-deps" in opts.flags:
            doc["packages"] = [root.metadata()]
            doc["resolve"] = None
        else:
            graph = minicargo_graph(root, opts)
            vendor = Path(env("MRUSTC_SHIM_VENDOR_DIR")).resolve()
            packages = []
            for i, gp in enumerate(graph["packages"]):
                manifest_path = Path(gp["manifest_path"]).resolve()
                if i == graph["root"]:
                    packages.append(root)
                else:
                    packages.append(Package(manifest_path, CRATES_IO if vendor in manifest_path.parents else None))
            nodes = []
            for gp, p in zip(graph["packages"], packages):
                deps = {}
                for d in gp["deps"]:
                    dp = packages[d["package"]]
                    nd = deps.get(dp.id)
                    if nd is None:
                        # The name the dependent uses: a renamed dependency's key, else the library's name
                        lib = dp.lib_target()
                        name = d["key"] if d["key"] != d["name"] or lib is None else lib["name"]
                        nd = deps[dp.id] = {"name": name.replace("-", "_"), "pkg": dp.id, "dep_kinds": []}
                    kind = None if d["kind"] == "normal" else d["kind"]
                    if not any(k["kind"] == kind for k in nd["dep_kinds"]):
                        nd["dep_kinds"].append({"kind": kind, "target": None})
                nodes.append({
                    "id": p.id,
                    "dependencies": sorted(deps),
                    "deps": [deps[k] for k in sorted(deps)],
                    "features": sorted(gp["features"]),
                })
            doc["packages"] = [p.metadata() for p in packages]
            doc["resolve"] = {"nodes": nodes, "root": root.id}
    # (TOML dates in [package.metadata] become strings)
    json.dump(doc, sys.stdout, default=str)
    sys.stdout.write("\n")


def message(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def artifact_message(pkg, target, filename, features, executable=None):
    return {
        "reason": "compiler-artifact",
        "package_id": pkg.id,
        "manifest_path": str(pkg.manifest_path),
        "target": {k: v for k, v in target.items() if k != "required-features"},
        "profile": {"opt_level": "3", "debuginfo": 0, "debug_assertions": False,
                    "overflow_checks": False, "test": False},
        "features": features,
        "filenames": [str(filename)],
        "executable": str(executable) if executable else None,
        "fresh": False,
    }


def cargo_build(command, opts):
    crate_types = [t for v in opts.all("--crate-type") for t in v.split(",") if t]
    unsupported = set(crate_types) - {"cdylib", "staticlib", "rlib", "lib"}
    if unsupported:
        die(f"--crate-type {','.join(sorted(unsupported))} is not supported (Rust dylibs aren't)")
    if command == "build" and opts.rustc_args:
        die(f"unexpected arguments after `--`: {' '.join(opts.rustc_args)}")
    flags, where = env_rustflags()
    link_args = rustc_link_args(flags, where) + rustc_link_args(opts.rustc_args, "`cargo rustc --` arguments")

    pkg = Package(find_manifest(opts))
    # `cargo build -p member` at the workspace root (newsboat's Makefile: `cargo build --package libnewsboat-ffi`)
    package = opts.get("--package", "-p")
    if package and package != pkg.name:
        member = pkg.workspace_member(package)
        if member is None:
            die(f"--package {package}: no such package in the workspace of {pkg.manifest_path}")
        pkg = member
    if pkg.name is None:
        die(f"{pkg.manifest_path} is a virtual manifest; name the member with --package")

    host = env("MRUSTC_SHIM_HOST")
    target = opts.get("--target") or os.environ.get("CARGO_BUILD_TARGET")
    check_platforms([target])
    out_dir = pkg.target_dir(opts) / (target or "") / "release"
    out_dir.mkdir(parents=True, exist_ok=True)

    lib = pkg.lib_target()
    lib_only = "--lib" in opts.flags
    if lib_only and lib is None:
        die(f"no library target in package `{pkg.name}`")
    lib_types = crate_types or (lib["crate_types"] if lib else [])
    builds_cdylib = lib is not None and "cdylib" in lib_types

    features = requested_features(opts, pkg.manifest)
    bins = opts.all("--bin")
    argv = [env("MRUSTC_SHIM_MINICARGO"), str(pkg.dir),
            "-L", env("MRUSTC_SHIM_LIBDIR"),
            "-j", opts.get("--jobs", "-j") or env("MRUSTC_SHIM_JOBS"),
            "--vendor-dir", env("MRUSTC_SHIM_VENDOR_DIR"),
            "--output-dir", str(out_dir)] + feature_args(opts, pkg)
    if lib_only:
        argv.append("--lib")
    if crate_types:
        argv += ["--crate-type", ",".join(crate_types)]
    for b in bins:
        argv += ["--bin", b]
    for a in link_args:
        argv += ["--link-arg", a]
    if builds_cdylib:
        argv += ["--panic", os.environ.get("MRUSTC_SHIM_PANIC") or "unwind"]

    if run_minicargo(argv) != 0:
        message({"reason": "build-finished", "success": False})
        sys.exit(101)

    if builds_cdylib:
        suffix = ".dylib" if "-apple-" in host else ".so"
        dylib = out_dir / f"lib{lib['name']}{suffix}"
        if not dylib.is_file():
            die(f"minicargo did not produce {dylib}")
        message(artifact_message(pkg, dict(lib, kind=["cdylib"], crate_types=["cdylib"]), dylib, features))
    if not lib_only or bins:
        for t in pkg.bin_targets():
            if bins and t["name"] not in bins:
                continue
            exe = out_dir / t["name"]
            if not exe.is_file():
                # e.g. its required-features are not enabled
                continue
            message(artifact_message(pkg, t, exe, features, executable=exe))
    message({"reason": "build-finished", "success": True})


def cargo_main(args):
    if args and args[0].startswith("+"):
        args = args[1:]     # +toolchain
    if not args:
        die("no command given")
    if args[0] in ("-V", "--version"):
        print(f"cargo {os.environ.get('MRUSTC_TARGET_VER', '1.90')}.0 (minicargo)")
        return
    if args[0] in ("update", "generate-lockfile"):
        sys.stderr.write(f"{TOOL} (mrustc PortGroup stand-in): `cargo {args[0]}`: nothing to do, minicargo resolves "
                         "from the vendored crates (cargo.crates), not from Cargo.lock\n")
        return
    command, opts = args[0], parse_options(args[1:])
    if command == "metadata":
        cargo_metadata(opts)
    elif command in ("build", "rustc"):
        cargo_build(command, opts)
    else:
        die(f"`cargo {command}` is not supported")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("cargo", "rustc"):
        sys.stderr.write("usage: cargo-shim.py cargo|rustc <arguments>\n")
        sys.exit(2)
    TOOL = sys.argv[1]
    if TOOL == "rustc":
        rustc_main(sys.argv[2:])
    else:
        cargo_main(sys.argv[2:])
