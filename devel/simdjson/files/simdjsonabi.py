#!/usr/bin/env python3
# simdjsonabi: the ABI gate for the devel/simdjson port's pinned install
# name (libsimdjson.<major>.dylib).  Upstream's tools/release.py bumps the
# soversion on every minor release (5.0.8 bumped it with no code change at
# all); the port does not, so each update must show that nothing the dylib
# shares with its dependents changed.
#
#   simdjsonabi.py abi OLD NEW          two extracted source trees
#   simdjsonabi.py abi REPO vOLD vNEW   two refs of a simdjson git clone
#
# What crosses the dylib boundary: everything src/ compiles, and the
# declarations it shares with a dependent - the implementation and
# dom_parser_implementation hierarchies (a dependent's ondemand and dom
# parsers create the parser implementation through get_active_implementation(),
# call it through its vtable and read its fields inline), dom::document and
# the tape encoding (stage 2 writes the tape the dependent reads), error_code
# and its table, the exported lookup tables, to_chars, SIMDJSON_PADDING and
# the size limits.  abi fails (exit 1) when src/ differs in anything but
# comments, when one of those headers differs in anything but comments and
# the bodies of inline functions, or when the inline code that sizes the
# buffers the dylib writes (CONTRACT) differs at all.  Other header changes
# (ondemand, builder, serialization, number parsing) compile into the
# dependent and are listed for information.  Text-level, no compiler: a failure means read the
# diff, a pass is necessary, not sufficient - read the release notes too.
import difflib, fnmatch, os, re, subprocess, sys

BOUNDARY = [
    'include/simdjson/base.h',
    'include/simdjson/common_defs.h',
    'include/simdjson/error.h',
    'include/simdjson/implementation.h',
    'include/simdjson/implementation_detection.h',
    'include/simdjson/portability.h',
    'include/simdjson/*/implementation.h',
    'include/simdjson/generic/dom_parser_implementation.h',
    'include/simdjson/internal/dom_parser_implementation.h',
    'include/simdjson/internal/*_tables.h',
    'include/simdjson/internal/atomic_ptr.h',
    'include/simdjson/internal/tape_type.h',
    'include/simdjson/dom/document.h',
]

# Inline code in the dependent that sizes the buffers the dylib writes
# (document::allocate, the parsers' capacity handling): compared in full.
CONTRACT = [
    'include/simdjson/dom/document-inl.h',
    'include/simdjson/dom/parser-inl.h',
    'include/simdjson/generic/ondemand/parser-inl.h',
]


class Tree:
    def __init__(self, root, ref=None):
        self.root, self.ref = root, ref

    def files(self):
        if self.ref is None:
            out = []
            for d in ('include', 'src'):
                for dp, _, fs in os.walk(os.path.join(self.root, d)):
                    out += [os.path.relpath(os.path.join(dp, f), self.root)
                            for f in fs]
            return set(out)
        r = subprocess.run(['git', '-C', self.root, 'ls-tree', '-r',
                            '--name-only', self.ref, 'include/', 'src/'],
                           capture_output=True, text=True, check=True)
        return set(r.stdout.split())

    def read(self, path):
        if self.ref is None:
            with open(os.path.join(self.root, path), errors='replace') as f:
                return f.read()
        r = subprocess.run(['git', '-C', self.root, 'show',
                            f'{self.ref}:{path}'], capture_output=True,
                           text=True, check=True)
        return r.stdout


TOKEN = re.compile(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|'
                   r'/\*.*?\*/|//[^\n]*', re.S)


def literal(m):
    t = m.group(0)
    if t[0] not in '"\'':
        return ' '
    # Keep the value, but not as a brace or semicolon the scanner would see
    # (tape_type.h: START_OBJECT = '{').
    return t.replace('{', '\\x7b').replace('}', '\\x7d').replace(';', '\\x3b')


def strip_comments(s):
    return re.sub(r'\\\n', ' ', TOKEN.sub(literal, s))


SCOPE = re.compile(r'\b(class|struct|union|enum|namespace)\b|^extern\s*"C"$')
FUNC_TAIL = re.compile(r'\)\s*(const|noexcept(\s*\([^)]*\))?|override|final|'
                       r'volatile|&|&&|->\s*[\w:<>,\s\*&]+|\s)*$')
CTOR_INIT = re.compile(r'\)\s*(noexcept\s*)?:(?!:)')


def skeleton(s):
    """Declarations only: inline function bodies dropped, initialisers kept."""
    out, stack, head = [], [], []
    for line in strip_comments(s).split('\n'):
        if line.lstrip().startswith('#'):
            if 'body' not in stack:
                out.append(' '.join(line.split()) + '\n')
            continue
        for ch in line + '\n':
            if ch == '{':
                h = ' '.join(''.join(head).split())
                if 'body' in stack or FUNC_TAIL.search(h):
                    kind = 'body'
                elif CTOR_INIT.search(h):
                    # a{1} in a member initializer list, then the body
                    kind = 'init' if re.search(r'[\w>]$', h) else 'body'
                elif SCOPE.search(h):
                    kind = 'scope'
                else:
                    kind = 'init'
                if 'body' not in stack:
                    out.append({'scope': ' {', 'body': ' {...}',
                                'init': '{'}[kind])
                stack.append(kind)
                if kind != 'init':
                    head = []
            elif ch == '}':
                kind = stack.pop() if stack else 'scope'
                if 'body' not in stack:
                    out.append('}\n' if kind == 'scope' else
                               '}' if kind == 'init' else '')
                if kind != 'init':
                    head = []
                else:
                    head.append(ch)
            elif ch == ';':
                if 'body' not in stack:
                    out.append(';\n')
                head = []
            else:
                if 'body' not in stack:
                    out.append(ch)
                head.append(ch)
    lines = (' '.join(l.split()) for l in ''.join(out).split('\n'))
    return [l for l in lines if l]


def full(s):
    lines = (' '.join(l.split()) for l in strip_comments(s).split('\n'))
    return [l for l in lines if l]


def boundary(path):
    return any(fnmatch.fnmatch(path, p) for p in BOUNDARY)


def show_diff(path, a, b):
    for l in difflib.unified_diff(a, b, f'old/{path}', f'new/{path}',
                                  lineterm='', n=1):
        print('    ' + l)


def kind(path):
    if path.startswith('src/'):
        return 'src'
    if path in CONTRACT:
        return 'contract'
    return 'boundary' if boundary(path) else None


def abi(old, new):
    of, nf = old.files(), new.files()
    fail = False
    for path in sorted(of | nf):
        k = kind(path)
        if k is None:
            continue
        if path not in of or path not in nf:
            print(f'{k}: {"added" if path in nf else "removed"} {path}')
            fail = True
            continue
        a, b = old.read(path), new.read(path)
        if a == b:
            continue
        f = skeleton if k == 'boundary' else full
        if f(a) != f(b):
            print(f'{k}: {path}')
            show_diff(path, f(a), f(b))
            fail = True
    other = [p for p in sorted(of | nf) if kind(p) is None and
             (p not in of or p not in nf or old.read(p) != new.read(p))]
    if other:
        print('header-only changes (compiled into dependents):')
        for p in other:
            print(f'    {p}')
    print('ABI: review the differences above' if fail else
          'ABI: no difference in what the dylib shares with dependents')
    return 1 if fail else 0


def main(argv):
    if len(argv) == 4 and argv[1] == 'abi':
        return abi(Tree(argv[2]), Tree(argv[3]))
    if len(argv) == 5 and argv[1] == 'abi':
        return abi(Tree(argv[2], argv[3]), Tree(argv[2], argv[4]))
    sys.stderr.write('usage: simdjsonabi.py abi OLD NEW\n'
                     '       simdjsonabi.py abi REPO vOLD vNEW\n')
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
