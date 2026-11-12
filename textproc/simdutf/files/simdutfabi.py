#!/usr/bin/env python3
# simdutfabi: the ABI gate for the textproc/simdutf port's pinned install
# name (libsimdutf.<major>.dylib).  Upstream bumps the soversion on every
# minor release; the port does not, so each update must show that nothing a
# dependent binds to changed incompatibly.
#
#   simdutfabi.py abi REPO OLD NEW   compare two refs of a simdutf git clone
#   simdutfabi.py users DIR...       check dependents' sources
#
# abi fails (exit 1) when an exported free function (C++ or the C API) is
# removed - including one that became a header-only inline/constexpr, whose
# symbol is then gone - or changes its parameter list, when an enumerator
# changes its value, or when a public struct loses or reorders a member.
# Additions pass; an enumerator name that disappears with no value change
# is reported as source-level only.  Changes to the
# virtual interface of simdutf::implementation are reported but do not
# fail: the port's dependents never call through it, which `users` checks.
# users fails when a source file outside a vendored simdutf copy uses the
# implementation objects (get_active_implementation & co.).
# Text-level parsing, no compiler: treat a pass as necessary, not
# sufficient, and read the release notes too.
import os, re, subprocess, sys


def headers(repo, ref):
    r = subprocess.run(['git', '-C', repo, 'ls-tree', '-r', '--name-only', ref,
                        'include/'], capture_output=True, text=True)
    return [h for h in r.stdout.split() if h.endswith('.h') and
            '/scalar/' not in h and '/internal/' not in h]


def show(repo, ref, path):
    r = subprocess.run(['git', '-C', repo, 'show', f'{ref}:{path}'],
                       capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ''


def strip(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    return re.sub(r'//[^\n]*', '', s)


def norm(s):
    return re.sub(r'\s+', ' ', s).strip()


def split_impl(s):
    m = re.search(r'\nclass implementation\b.*?\n};', s, re.S)
    if not m:
        return s, ''
    return s[:m.start()] + s[m.end():], m.group(0)


def free_functions(text):
    out = {}
    pat = re.compile(r'(?:^|\n)((?:simdutf_warn_unused\s+)?[A-Za-z_:<>\s\*&0-9]+?'
                     r'\b([A-Za-z_][A-Za-z_0-9]*)\s*\(([^;{}]*?)\)\s*(?:noexcept)?\s*;)')
    for d in pat.finditer(text):
        head = d.group(1)
        if re.search(r'\b(inline|template|constexpr|simdutf_really_inline|return|'
                     r'typedef|using|virtual|static_assert)\b', head):
            continue
        params = norm(re.sub(r'=[^,]*', '', d.group(3)))
        out.setdefault(d.group(2), set()).add(params)
    return out


def virtuals(cls):
    return [d.group(1) + '(' + norm(d.group(2)) + ')' for d in
            re.finditer(r'virtual[^;{]*?\b([a-z_0-9]+)\s*\(([^)]*)\)', cls, re.S)]


def types(text):
    enums, structs = {}, {}
    for d in re.finditer(r'\b(enum(?:\s+class)?|struct)\s+([A-Za-z_]\w*)\s*'
                         r'(?::\s*[\w:]+\s*)?\{(.*?)\};', text, re.S):
        body = norm(d.group(3))
        if d.group(1).startswith('enum'):
            vals, nxt = {}, 0
            for m in (norm(m) for m in body.split(',') if norm(m)):
                name, _, val = (x.strip() for x in m.partition('='))
                if val:
                    try:
                        nxt = int(val, 0)
                    except ValueError:
                        nxt = None
                    vals[name] = val if nxt is None else nxt
                else:
                    vals[name] = nxt if nxt is not None else f'{prev}+1'
                prev = name
                nxt = nxt + 1 if isinstance(nxt, int) else None
            enums[d.group(2)] = vals
        else:
            structs[d.group(2)] = [norm(m) for m in body.split(';')
                                   if norm(m) and '(' not in m]
    consts = dict((m.group(1), m.group(2).strip()) for m in re.finditer(
        r'constexpr\s+[\w:]+\s+([A-Za-z_]\w*)\s*=\s*([^;]+);', text))
    return enums, structs, consts


def load(repo, ref):
    fns, en, st, co, vt = {}, {}, {}, {}, []
    for h in headers(repo, ref):
        s = strip(show(repo, ref, h))
        if not s:
            continue
        rest, cls = split_impl(s)
        if cls:
            vt = virtuals(cls)
        for k, v in free_functions(rest).items():
            fns.setdefault(k, set()).update(v)
        e, t, c = types(rest)
        en.update(e); st.update(t); co.update(c)
    return fns, en, st, co, vt


def abi(repo, old, new):
    of, oe, os_, oc, ov = load(repo, old)
    nf, ne, ns, nc, nv = load(repo, new)
    if not of or not nf:
        sys.exit(f'no declarations found for {old} or {new}')
    bad, notes = [], []
    for name, sigs in sorted(of.items()):
        if name not in nf:
            bad.append(f'removed function: {name}')
            continue
        for sig in sorted(sigs - nf[name]):
            bad.append(f'changed function: {name}({sig})')
    for enum, vals in sorted(oe.items()):
        if enum not in ne:
            notes.append(f'enum {enum} gone (source-level)')
            continue
        for k, v in vals.items():
            if k in ne[enum]:
                if ne[enum][k] != v:
                    bad.append(f'enumerator {enum}::{k}: {v} -> {ne[enum][k]}')
            elif str(nc.get(k)) != str(v):
                notes.append(f'enumerator {enum}::{k} gone (source-level)')
    for name, members in sorted(os_.items()):
        if name not in ns:
            bad.append(f'removed struct: {name}')
        elif ns[name][:len(members)] != members:
            bad.append(f'changed struct: {name}: {members} -> {ns[name]}')
    added = sorted(set(nf) - set(of))
    print(f'{old} -> {new}: {len(of)} -> {len(nf)} exported functions, '
          f'{len(oe)} -> {len(ne)} enums, {len(os_)} -> {len(ns)} structs')
    if added:
        print('  added functions: ' + ', '.join(added))
    grown = sorted(n for n in set(oe) & set(ne) if len(ne[n]) > len(oe[n]))
    grown += sorted(n for n in set(os_) & set(ns) if len(ns[n]) > len(os_[n]))
    if grown:
        print('  appended members: ' + ', '.join(grown))
    for n in notes:
        print('  note ' + n)
    common = [v for v in ov if v in nv]
    moved = [v for v in common if nv.index(v) != ov.index(v)]
    print(f'  implementation vtable: {len(ov)} -> {len(nv)} virtuals, '
          f'{len(moved)} moved slot (informational, see `users`)')
    for b in bad:
        print('  BREAK ' + b)
    print('  RESULT: ' + ('incompatible: bump the pinned name' if bad else
                          'compatible for free-function users'))
    return 1 if bad else 0


USE = re.compile(r'get_active_implementation|get_available_implementations|'
                 r'get_default_implementation|builtin_implementation|'
                 r'\bsimdutf::implementation\b|available_implementation_list')
SRC = ('.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp', '.mm', '.m')


def users(dirs):
    hits = 0
    for top in dirs:
        for root, subdirs, files in os.walk(top):
            subdirs[:] = [d for d in subdirs if d not in ('.git', 'simdutf')]
            for f in files:
                if not f.endswith(SRC) or f.startswith('simdutf'):
                    continue
                p = os.path.join(root, f)
                try:
                    lines = open(p, errors='replace').read().splitlines()
                except OSError:
                    continue
                for i, l in enumerate(lines, 1):
                    if USE.search(l):
                        hits += 1
                        print(f'{p}:{i}: {l.strip()}')
    print(f'implementation-object uses: {hits}')
    return 1 if hits else 0


if __name__ == '__main__':
    if len(sys.argv) == 5 and sys.argv[1] == 'abi':
        sys.exit(abi(*sys.argv[2:]))
    if len(sys.argv) >= 3 and sys.argv[1] == 'users':
        sys.exit(users(sys.argv[2:]))
    sys.exit(__doc__ if __doc__ else
             'usage: simdutfabi.py abi REPO OLD NEW | users DIR...')
