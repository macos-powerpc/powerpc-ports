// d8 Maglev battery — v8-14.6 ppc32 Darwin port, ppc32 Maglev layer
// (node/v8-14.6-maglev-ppc32-design.md, section 6.2).
// Run:  d8 --allow-natives-syntax --maglev d8-smoke-maglev.js
// then: d8 --allow-natives-syntax --maglev --maglev-assert d8-smoke-maglev.js
// and:  d8 --allow-natives-syntax --maglev --maglev-assert --stress-maglev d8-smoke-maglev.js
// --maglev is required while the ppc32 default is staged off.  A separate
// file because %-intrinsics are a SyntaxError without --allow-natives-syntax.
// Under --stress-maglev copies can tier up early on partial feedback: a tier
// FAIL there is noise, a value FAIL is not.
// Prints "RUN <name>" before each group; PASS/FAIL per check; exits 1 if any
// check failed.  skip= as in d8-smoke.js:  d8 ... -- skip=maglev-frames
// Every test function is re-evaluated from its source into fresh copies (own
// SharedFunctionInfo, feedback and code): a %NeverOptimizeFunction reference
// and Maglev copies, warmed with the input types they are tested on, compiled
// by %OptimizeMaglevOnNextCall and tier-checked after their first call.
// Results must equal both the reference (interpreter) result and a literal.
// An input that must deopt runs on its own fresh copy after one ordinary
// call.  Int32 inputs stay in the 31-bit Smi range; 2^31 edges are built
// inside the function (a + b) so the int32 nodes see them untagged.
// Diagnose with --trace-opt --trace-deopt, or dump one function's code:
//   --print-maglev-code --maglev-print-filter=fib
// Groups (ppc32 nodes and helpers, design sections 4.2-4.5):
//   maglev-available   — Maglev tiers up at all (else every tier check fails)
//   maglev-int32       — xor-sign overflow nodes, mulhw multiply, divide,
//                        modulus (0059 ModU32), TrySmiTagInt32, SmiSubConstant
//   maglev-float64     — Float64Min/Max (MinF64/MaxF64 zero), Sqrt/Modulus
//                        as C calls, Ieee754 calls, no Float64Round, clz32
//   maglev-conversions — TruncateDoubleToInt32, TryChangeFloat64ToIndex,
//                        typed-array stores, CheckFloat64SameValue, -0 boxing
//   maglev-bigendian   — DataView keep/reverse incl. lwbrx Float64, native BE
//                        typed-array layout (FAILs on LE hosts by design),
//                        JumpIfHoleNan, NaN silencing, string char loads
//   maglev-frames      — recursion, >8 tagged slots across a call, OSR,
//                        exception handlers, arguments/rest, context cells

var failures = 0, checks = 0;
function show(v) {
  if (Array.isArray(v)) return "[" + v.map(show).join(",") + "]";
  if (typeof v === "string") return JSON.stringify(v);
  return Object.is(v, -0) ? "-0" : String(v);
}
function same(a, b) {
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    for (var i = 0; i < a.length; i++) if (!same(a[i], b[i])) return false;
    return true;
  }
  return Object.is(a, b);
}
function eq(name, actual, expected) {
  checks++;
  if (same(actual, expected)) {
    print("PASS " + name);
  } else {
    failures++;
    print("FAIL " + name + ": got " + show(actual) + ", want " + show(expected));
  }
}
// One check: the Maglev result, the reference result and the literal agree
// (ok === false: the copy was not running Maglev code before the call).
function eqm(name, got, ref, want, ok) {
  checks++;
  if (ok !== false && same(got, want) && same(ref, want)) {
    print("PASS " + name);
    return true;
  }
  failures++;
  print("FAIL " + name + (ok === false ? " (copy was not Maglev code before this call)" : "") +
        ": maglev " + show(got) + ", interpreter " + show(ref) + ", want " + show(want));
  return false;
}
var skipped = [];
var skip_prefixes = (typeof arguments === "object" ? Array.prototype.slice.call(arguments) : [])
  .filter(function (a) { return a.indexOf("skip=") === 0; })
  .map(function (a) { return a.slice(5).split(","); })
  .reduce(function (acc, l) { return acc.concat(l); }, [])
  .filter(function (p) { return p.length > 0; });
function run(name, fn) {
  for (var i = 0; i < skip_prefixes.length; i++) {
    if (name.indexOf(skip_prefixes[i]) === 0) {
      skipped.push(name);
      print("SKIP " + name + " (skip=" + skip_prefixes[i] + ")");
      return;
    }
  }
  print("RUN  " + name);
  try { fn(); } catch (e) { failures++; checks++; print("FAIL " + name + " threw: " + e); }
}

// ---- Maglev harness (kept in the interpreter itself) ----
var copies = 0;
function copyOf(f) {
  // Indirect eval at global scope; the counter defeats the eval cache.
  return (0, eval)("(" + f + ")\n//" + copies++);
}
function argsOf(a) { return typeof a === "function" ? a() : a; }
function value(fn, args, post) {
  var a = argsOf(args), v;
  try { v = fn.apply(null, a); } catch (e) { v = "threw " + e.name + ": " + e.message; }
  return post ? post(v, a) : v;
}
function maglevCopy(make, warm) {
  var g = make();
  %PrepareFunctionForOptimization(g);
  for (var r = 0; r < 2; r++)
    for (var i = 0; i < warm.length; i++) value(g, warm[i]);
  %OptimizeMaglevOnNextCall(g);
  return g;
}
function caseLabel(c) {
  return c[2] !== undefined ? c[2] : Array.isArray(c[0]) ? show(c[0]) : "case";
}
// mg(name, f, warm, cases, deopts, opts)
//   warm    argument lists for the warm-up (run twice)
//   cases   [args, want, label?] that must not deopt, on one Maglev copy;
//           tier check after the first call, then one vector check
//           (opts.each: one check per case)
//   deopts  [label, args, want] that must deopt, each on a fresh copy after
//           one call of cases[0]; opts.after re-runs cases[0] on the first
//   args may be a function returning the list (fresh objects per call);
//   opts.post(ret, args) observes side effects; opts.make builds closures
//   (the reference then replays the warm-up too).
function mg(name, f, warm, cases, deopts, opts) {
  opts = opts || {};
  var make = opts.make || function () { return copyOf(f); };
  var ref = make(), i, r;
  %NeverOptimizeFunction(ref);
  if (opts.make)
    for (r = 0; r < 2; r++)
      for (i = 0; i < warm.length; i++) value(ref, warm[i]);
  var g = maglevCopy(make, warm), got = [], refs = [], wants = [];
  for (i = 0; i < cases.length; i++) {
    got.push(value(g, cases[i][0], opts.post));
    if (i === 0) eq(name + " tier", %ActiveTierIsMaglev(g), true);
    refs.push(value(ref, cases[i][0], opts.post));
    wants.push(cases[i][1]);
    if (opts.each) eqm(name + " " + caseLabel(cases[i]), got[i], refs[i], wants[i]);
  }
  if (!opts.each && cases.length === 1) {
    eqm(name + " " + caseLabel(cases[0]), got[0], refs[0], wants[0]);
  } else if (!opts.each && !eqm(name + " (" + cases.length + " cases)", got, refs, wants)) {
    for (i = 0; i < cases.length; i++)
      if (!same(got[i], wants[i]) || !same(refs[i], wants[i]))
        print("     " + caseLabel(cases[i]) + ": maglev " + show(got[i]) +
              ", interpreter " + show(refs[i]) + ", want " + show(wants[i]));
  }
  deopts = deopts || [];
  for (i = 0; i < deopts.length; i++) {
    var h = maglevCopy(make, warm);
    value(h, cases[0][0], opts.post);
    var tiered = %ActiveTierIsMaglev(h);
    eqm(name + " deopt " + deopts[i][0], value(h, deopts[i][1], opts.post),
        value(ref, deopts[i][1], opts.post), deopts[i][2], tiered);
    if (i === 0 && opts.after)
      eqm(name + " after deopt", value(h, cases[0][0], opts.post),
          value(ref, cases[0][0], opts.post), cases[0][1]);
  }
}
function cat(a, b) { return a + b; }
function bytes(u8, n) { var r = []; for (var i = 0; i < n; i++) r.push(u8[i]); return r; }
// Callees that must stay real calls (never inlined into Maglev code).
function callee7(n) { return n * 7; }
function deep(x) { throw new RangeError("t" + x); }
function thrower(x) { if (x > 2) deep(x); return x; }
[show, same, eq, eqm, run, copyOf, argsOf, value, maglevCopy, caseLabel, mg,
 cat, bytes, callee7, deep, thrower].forEach(function (h) { %NeverOptimizeFunction(h); });

// Global property cells for CheckFloat64SameValue (kConstant cells holding a
// HeapNumber; Maglev checks the stored value against it and skips the store).
var mgc_mz = -0, mgc_nan = NaN, mgc_dbl = 1.5;

run("maglev-available", function () {
  var on = %IsMaglevEnabled();
  eq("maglev enabled", on, true);
  if (!on) print("     -> pass --maglev (staged default-off on ppc32); every tier check below will FAIL");
  function triv(a, b) { return a + b; }
  var g = maglevCopy(function () { return copyOf(triv); }, [[1, 2], [3, 4]]);
  eq("triv 5+6", g(5, 6), 11);
  var t = %ActiveTierIsMaglev(g);
  eq("triv tier", t, true);
  if (!t) print("     -> no Maglev code: build without V8_ENABLE_MAGLEV (d8 printed \"Maglev is not enabled.\"), " +
                "--maglev missing, or the compile bailed out (rerun with --trace-opt)");
  eq("triv deopt round trip", g("a", "b"), "ab");
  eq("triv back in the interpreter", %ActiveTierIsMaglev(g), false);
});

run("maglev-int32", function () {
  // Int32AddWithOverflow (xor-sign helper); results >= 2^30 box (TrySmiTagInt32).
  function add(a, b) { return a + b; }
  mg("add", add, [[1, 2], [-3, 4]], [
    [[1073741823, 1073741823], 2147483646],
    [[-1073741824, -1073741824], -2147483648],
    [[5, -7], -2]]);
  // Same input register on both sides.
  function addx(a, b) { var s = a + b; return s + s; }
  mg("s+s", addx, [[1, 2], [3, -4]], [
    [[3, 4], 14],
    [[-1073741824, 0], -2147483648]],
    [["overflow", [1073741823, 1073741823], 4294967292]], {after: true});
  function subx(a) { var b = a - a; return b; }
  mg("a-a", subx, [[3], [-9]], [[[7], 0], [[-1073741824], 0]]);
  function add3(a, b, c) { return (a + b) + c; }
  mg("kMaxInt+1", add3, [[1, 2, 3], [4, -5, 6]], [[[1, 2, 3], 6]],
     [["overflow", [1073741823, 1073741823, 2], 2147483648]]);
  function sub3(a, b, c) { return (a + b) - c; }
  mg("kMinInt-1", sub3, [[1, 2, 3], [4, -5, 6]], [[[1, 2, 3], 0]],
     [["overflow", [-1073741824, -1073741824, 1], -2147483649]]);
  // Int32NegateWithOverflow: kMinInt and 0 (-0) deopt.
  function neg(a, b) { var y = a + b; return -y; }
  mg("negate", neg, [[2, 3], [-4, 1]], [
    [[2, 3], -5],
    [[1073741823, 1073741823], -2147483646]],
    [["-kMinInt", [-1073741824, -1073741824], 2147483648],
     ["-0", [0, 0], -0]]);
  // Int32AbsWithOverflow on an int32 value.
  function abs(a, b) { return Math.abs((a + b) | 0); }
  mg("abs", abs, [[-2, -3], [4, 1]], [[[-2, -3], 5], [[2, 3], 5]],
     [["abs(kMinInt)", [-1073741824, -1073741824], 2147483648]]);
  // Int32MultiplyWithOverflow: mulhw/mullw high-word test, -0 via the operand signs.
  function mul(a, b) { return a * b; }
  mg("multiply", mul, [[6, 7], [-3, 4]], [
    [[6, 7], 42],
    [[65536, 16384], 1073741824],
    [[-65536, 32768], -2147483648],
    [[-5, -5], 25]],
    [["2^31", [65536, 32768], 2147483648],
     ["(-5)*0", [-5, 0], -0],
     ["0*(-5)", [0, -5], -0]], {after: true});
  // Int32DivideWithOverflow: non-integral, /0 and -0 deopt.
  function div(a, b) { return a / b; }
  mg("divide", div, [[6, 3], [-8, 2]], [[[6, 3], 2], [[-6, 3], -2]],
     [["7/2", [7, 2], 3.5], ["7/0", [7, 0], Infinity], ["0/-5", [0, -5], -0]],
     {after: true});
  function divw(a, b, c) { return (a + b) / c; }
  mg("divide kMinInt", divw, [[4, 2, 2], [9, -3, 3]], [[[4, 2, 2], 3]],
     [["kMinInt/-1", [-1073741824, -1073741824, -1], 2147483648]]);
  // Int32ModulusWithOverflow: power-of-2 mask, negative operands (ModU32).
  function mod(a, b) { return a % b; }
  mg("modulus", mod, [[13, 8], [7, 3], [-7, 3]], [
    [[13, 8], 5], [[-13, 8], -5], [[-7, 3], -1], [[7, -3], 1]],
    [["5%0", [5, 0], NaN], ["-6%3", [-6, 3], -0]], {after: true});
  function modw(a, b, c) { return (a + b) % c; }
  mg("modulus wide", modw, [[1, 2, 3], [5, 6, 4]], [
    [[1073741823, 1073741823, 8], 6],
    [[-1073741824, -1073741824, 3], -2]],
    [["kMinInt%-1", [-1073741824, -1073741824, -1], -0]]);
  function modx(a) { return a % a; }
  mg("a%a", modx, [[5], [7]], [[[5], 0]], [["-5%-5", [-5], -0]]);
  // Int32Increment/DecrementWithOverflow; the deopt is mid-function with
  // the kMaxInt/kMinInt intermediate live in a register.
  function inc(a, b) { var s = a + b; s++; s++; return s; }
  mg("increment", inc, [[5, 5], [1, 2]], [[[5, 5], 12], [[1073741823, 0], 1073741825]],
     [["kMaxInt++", [1073741823, 1073741823], 2147483648]], {after: true});
  function dec(a, b) { var s = a + b; s--; s--; return s; }
  mg("decrement", dec, [[5, 5], [1, 2]], [[[5, 5], 8], [[-1073741824, 0], -1073741826]],
     [["kMinInt--", [-1073741824, -1073741823], -2147483649]]);
  // x + 1 / x - 1 leaving the Smi range.
  function inc1(x) { return x + 1; }
  mg("x+1", inc1, [[5], [-9]], [[[5], 6], [[1073741823], 1073741824]]);
  function dec1(x) { return x - 1; }
  mg("x-1", dec1, [[5], [-9]], [[[5], 4], [[-1073741824], -1073741825]]);
  // Shifts: count masked to 5 bits; >>> results >= 2^31.
  function sh(a, b) { return [a << b, a >> b, a >>> b]; }
  mg("shifts", sh, [[1, 31], [-1, 0], [5, 2]], [
    [[5, 0], [5, 5, 5]],
    [[1, 31], [-2147483648, 0, 0]],
    [[-1, 31], [-2147483648, -1, 1]],
    [[1, 33], [2, 0, 0]],
    [[-8, 32], [-8, -8, 4294967288]],
    [[-1, -1], [-2147483648, -1, 1]],
    [[1024, 35], [8192, 128, 128]]]);
  function bw(a, b) { return [a & b, a | b, a ^ b, ~a]; }
  mg("bitwise", bw, [[12, 10], [-3, 6]], [
    [[-1, 252645135], [252645135, -1, -252645136, 0]],
    [[-1073741824, 1073741823], [0, -1, -1, 1073741823]],
    [[-5, 3], [3, -5, -8, 4]]]);
  // CheckedSmiTagInt32 (TrySmiTagInt32) storing into Smi elements.
  var SA = [1, 2, 3];
  function stsmi(arr, a, b) { arr[0] = a + b; return arr[0]; }
  mg("smi store", stsmi, [[SA, 3, 4], [SA, -1, 2]], [[[SA, 3, 4], 7, "3+4"]],
     [["2^30", [SA, 1073741823, 1], 1073741824]]);
  // CheckedSmiDecrement = SmiSubConstant (Array.prototype.pop length).
  function pop(arr) { var v = arr.pop(); return v * 1000 + arr.length; }
  mg("pop", pop, [function () { return [[4, 5]]; }, function () { return [[6]]; }], [
    [function () { return [[1, 2, 3]]; }, 3002, "[1,2,3]"],
    [function () { return [[7]]; }, 7000, "[7]"]]);
});

run("maglev-float64", function () {
  // Float64 arithmetic nodes.
  function farith(a, b) { return [a + b, a - b, a * b, a / b]; }
  mg("arith", farith, [[1.5, 2.25], [-3.5, 0.5]], [
    [[0.1, 0.2], [0.30000000000000004, -0.1, 0.020000000000000004, 0.5]],
    [[-0, -0], [-0, 0, 0, NaN]],
    [[-0, 0], [0, -0, -0, NaN]],
    [[1e308, 1e308], [Infinity, 0, Infinity, 1]],
    [[Infinity, -Infinity], [NaN, Infinity, -Infinity, NaN]],
    [[1.5, -0], [1.5, 1.5, -0, -Infinity]],
    [[536870912.5, 536870911.5], [1073741824, 1, 288230376151711740, 1.0000000018626451]]]);
  // Float64ToTagged: integral results become Smis (2^30 must box), -0 stays.
  function fsum(a, b) { return a + b; }
  mg("sum tagged", fsum, [[1.5, 2.25], [-3.5, 0.25]], [
    [[0.1, 0.2], 0.30000000000000004],
    [[536870912.5, 536870911.5], 1073741824],
    [[0.75, 0.25], 1],
    [[-0.5, 0.5], 0],
    [[-0, -0], -0]]);
  // Float64Modulus = fmod C call: doubles live across it must survive.
  function fmod(a, b) { var x = a * 1.5, y = b * 2.5, z = a + b; var m = a % b; return [m, x + y + z + m]; }
  mg("modulus", fmod, [[5.5, 2], [7.25, 1.5]], [
    [[5.5, 2], [1.5, 22.25]],
    [[-5.5, 2], [-1.5, -8.25]],
    [[5.5, -2], [1.5, 8.25]],
    [[-0, 1.5], [-0, 5.25]],
    [[1.5, 0], [NaN, NaN]],
    [[Infinity, 1], [NaN, NaN]],
    [[1.5, Infinity], [1.5, Infinity]]]);
  // Float64Exponentiate (**) and Float64Ieee754Binary (Math.pow).
  function fpow(a, b) { var x = a * 3; var p = a ** b, q = Math.pow(a, b); return [p, q, x + p]; }
  mg("power", fpow, [[1.5, 2], [2.5, 0.5]], [
    [[1.5, 2], [2.25, 2.25, 6.75]],
    [[2, -2], [0.25, 0.25, 6.25]],
    [[-8, 1 / 3], [NaN, NaN, NaN]],
    [[-0, 3], [-0, -0, -0]],
    [[-0, -1], [-Infinity, -Infinity, -Infinity]],
    [[4, 0.5], [2, 2, 14]],
    [[NaN, 0], [1, 1, NaN]]]);
  // Float64Max/Float64Min -> MinF64/MaxF64 equal-operand branch (kDoubleRegZero).
  function mx(a, b) { return Math.max(a, b); }
  mg("max", mx, [[1.5, 2.5], [3.5, -1.25]], [
    [[0, -0], 0, "(+0,-0)"],
    [[-0, 0], 0, "(-0,+0)"],
    [[1.5, 1.5], 1.5, "(1.5,1.5)"],
    [[-0, -0], -0, "(-0,-0)"],
    [[NaN, 1], NaN, "(NaN,1)"],
    [[2.5, -1.5], 2.5, "(2.5,-1.5)"]], null, {each: true});
  function mn(a, b) { return Math.min(a, b); }
  mg("min", mn, [[1.5, 2.5], [3.5, -1.25]], [
    [[0, -0], -0, "(+0,-0)"],
    [[-0, 0], -0, "(-0,+0)"],
    [[1.5, 1.5], 1.5, "(1.5,1.5)"],
    [[-0, -0], -0, "(-0,-0)"],
    [[1, NaN], NaN, "(1,NaN)"],
    [[2.5, -1.5], -1.5, "(2.5,-1.5)"]], null, {each: true});
  // Float64Sqrt as a C call (libm sqrt) with live doubles around it.
  function fsq(x) { var a = x * 3, b = x + 0.25; var r = Math.sqrt(x); return [r, a + b + r]; }
  mg("sqrt", fsq, [[2.25], [6.25]], [
    [[2], [1.4142135623730951, 9.664213562373096]],
    [[2.25], [1.5, 10.75]],
    [[0], [0, 0.25]],
    [[-0], [-0, 0.25]],
    [[-1], [NaN, NaN]],
    [[Infinity], [Infinity, Infinity]],
    [[1e-300], [1e-150, 0.25]]]);
  // Float64Ieee754Unary C calls.
  function ieee(x) { return [Math.sin(x), Math.cos(x), Math.exp(x), Math.log(x)]; }
  mg("ieee754", ieee, [[0.5], [2.5]], [
    [[1], [0.8414709848078965, 0.5403023058681398, 2.718281828459045, 0]],
    [[-1], [-0.8414709848078965, 0.5403023058681398, 0.36787944117144233, NaN]],
    [[-0], [-0, 1, 1, -Infinity]],
    [[Infinity], [NaN, NaN, Infinity, Infinity]]]);
  // No Float64Round node on ppc32: the builtins run from Maglev code.
  function rnd(x) { return [Math.round(x), Math.floor(x), Math.ceil(x), Math.trunc(x)]; }
  mg("round/floor/ceil/trunc", rnd, [[1.25], [-3.75], [-0.25]], [
    [[2.5], [3, 2, 3, 2]],
    [[-2.5], [-2, -3, -2, -2]],
    [[-0.5], [-0, -1, -0, -0]],
    [[0.49999999999999994], [0, 0, 1, 0]],
    [[-0], [-0, -0, -0, -0]],
    [[4503599627370497], [4503599627370497, 4503599627370497, 4503599627370497, 4503599627370497]],
    [[1.5], [2, 1, 2, 1]]]);
  // Int32CountLeadingZeros (cntlzw) and the double-input path.
  function clz(x) { return [Math.clz32(x | 0), Math.clz32(x)]; }
  mg("clz32", clz, [[1.5], [3], [-2.5]], [
    [[1], [31, 31]], [[0], [32, 32]], [[-1], [0, 0]], [[2147483648], [0, 0]],
    [[0.5], [32, 32]], [[4294967296], [32, 32]], [[NaN], [32, 32]], [[3.7], [30, 30]]]);
});

run("maglev-conversions", function () {
  // TruncateDoubleToInt32: fctiwz fast path, DoubleToI builtin slow path.
  function tr(x) { return x | 0; }
  mg("x|0", tr, [[1.5], [-2.5], [3000000000.5]], [
    [[1.5], 1], [[-0.5], 0], [[2147483648], -2147483648], [[4294967297], 1],
    [[-2147483649], 2147483647], [[1e20], 1661992960], [[NaN], 0],
    [[Infinity], 0], [[-Infinity], 0], [[-0], 0], [[3000000000.5], -1294967296]]);
  function tr2(x) { var d = x * 2; return d | 0; }
  mg("(x*2)|0", tr2, [[0.75], [-1.25]], [
    [[0.75], 1], [[1073741824], -2147483648], [[5e19], 1661992960],
    [[-0.25], 0], [[NaN], 0], [[Infinity], 0]]);
  // CheckedObjectToIndex -> TryChangeFloat64ToIndex for HeapNumber keys.
  var ARR = [10, 20, 30], box = {v: 0.5};
  box.v = 1;
  var HN1 = box.v;   // double field: loads as a HeapNumber 1.0
  function ld(arr, k) { return arr[k]; }
  mg("index", ld, [[ARR, 0], [ARR, 2], [ARR, HN1], [ARR, -0]], [
    [[ARR, 1], 20, "1"], [[ARR, HN1], 20, "1.0"], [[ARR, -0], 10, "-0"]],
    [["1.5", [ARR, 1.5], undefined],
     ["2^31", [ARR, 2147483648], undefined],
     ["2^30", [ARR, 1073741824], undefined]]);
  // Int32/Uint32/Uint8 stores truncate; Uint8Clamped rounds half to even
  // (generic store, no Float64Round on ppc32).
  var TI32 = new Int32Array(1), TU32 = new Uint32Array(1), TU8 = new Uint8Array(1),
      TU8C = new Uint8ClampedArray(1);
  function tst(a, b, c, d, v) { a[0] = v; b[0] = v; c[0] = v; d[0] = v; return [a[0], b[0], c[0], d[0]]; }
  function T(v) { return [TI32, TU32, TU8, TU8C, v]; }
  mg("typed stores i32/u32/u8/u8c", tst, [T(1.25), T(-1.5), T(300.75)], [
    [T(1.5), [1, 1, 1, 2], "1.5"],
    [T(-1.5), [-1, 4294967295, 255, 0], "-1.5"],
    [T(255.5), [255, 255, 255, 255], "255.5"],
    [T(256), [256, 256, 0, 255], "256"],
    [T(-0), [0, 0, 0, 0], "-0"],
    [T(NaN), [0, 0, 0, 0], "NaN"],
    [T(4294967301), [5, 5, 5, 255], "2^32+5"],
    [T(4294967295), [-1, 4294967295, 255, 255], "2^32-1"],
    [T(0.5), [0, 0, 0, 0], "0.5"],
    [T(2.5), [2, 2, 2, 2], "2.5"],
    [T(254.5), [254, 254, 254, 254], "254.5"],
    [T(2147483648), [-2147483648, 2147483648, 0, 255], "2^31"]]);
  // CheckFloat64SameValue: a same-value store passes and is skipped, a
  // different value must deopt and store (-0 vs +0 is the sign test).  +v
  // types the value as Number (else Maglev deopts unconditionally) and keeps
  // the warm-up storing the cell's own HeapNumber (the cell stays kConstant).
  function st_mz(v) { mgc_mz = +v; }
  var g = maglevCopy(function () { return copyOf(st_mz); }, [[mgc_mz]]);
  g(mgc_mz);
  eq("same-value -0 tier", %ActiveTierIsMaglev(g), true);
  g(0 * -1);
  var kept = mgc_mz;
  g(0);
  eq("same-value -0 cell", [kept, mgc_mz], [-0, 0]);
  function st_nan(v) { mgc_nan = +v; }
  g = maglevCopy(function () { return copyOf(st_nan); }, [[mgc_nan]]);
  g(mgc_nan);
  eq("same-value NaN tier", %ActiveTierIsMaglev(g), true);
  g(0 / 0);
  kept = mgc_nan;
  g(1.5);
  eq("same-value NaN cell", [kept, mgc_nan], [NaN, 1.5]);
  function st_dbl(v) { mgc_dbl = +v; }
  g = maglevCopy(function () { return copyOf(st_dbl); }, [[mgc_dbl]]);
  g(mgc_dbl);
  eq("same-value 1.5 tier", %ActiveTierIsMaglev(g), true);
  g(3 / 2);
  kept = mgc_dbl;
  g(-1.5);
  eq("same-value 1.5 cell", [kept, mgc_dbl], [1.5, -1.5]);
  // Object.is on tagged doubles, and -0 surviving Float64ToTagged.
  function isz(v) { return [Object.is(v, -0), Object.is(v, 0)]; }
  mg("Object.is", isz, [[-0], [1.5]], [
    [[-0], [true, false]], [[0], [false, true]], [[1e-320], [false, false]],
    [[-1e-320], [false, false]], [[NaN], [false, false]]]);
  function fz(x) { var d = x * -1; return [Object.is(d, -0), Object.is(d, 0), d]; }
  mg("Object.is float64", fz, [[1.5], [-2.5]], [
    [[0], [true, false, -0]], [[-0], [false, true, 0]], [[2.5], [false, false, -2.5]]]);
});

run("maglev-bigendian", function () {
  // DataView Int8/16/32/Float64 (inlined): keep vs reverse, unaligned offsets.
  var DVB = new Uint8Array([0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18,
                            0x80, 0x01, 0xFE, 0xFF, 0x12, 0x34, 0x56, 0x78]);
  var DV = new DataView(DVB.buffer);
  function dvg(dv, o, le) { return [dv.getInt8(o), dv.getInt16(o, le), dv.getInt32(o, le), dv.getFloat64(o, le)]; }
  mg("dataview get", dvg, [[DV, 0, false], [DV, 8, true], [DV, 1, true]], [
    [[DV, 0, false], [64, 16393, 1074340347, 3.141592653589793], "o=0 BE"],
    [[DV, 0, true], [64, 2368, -81721024, 3.207375630676366e-192], "o=0 LE"],
    [[DV, 8, false], [-128, -32767, -2147352833, -2.775890302926003e-309], "o=8 BE"],
    [[DV, 8, true], [-128, 384, -130688, 4.691977069175095e+271], "o=8 LE"],
    [[DV, 1, false], [9, 2337, 153221972, 1.115336423963928e-264], "o=1 BE"],
    [[DV, 1, true], [9, 8457, 1425744137, -3.3622011793977055e-308], "o=1 LE"],
    [[DV, 5, true], [68, 11588, -2145899196, 3.6251617292653128e-217], "o=5 LE"]]);
  function dvgc(dv, o) {
    return [dv.getInt16(o, true), dv.getInt32(o, true), dv.getFloat64(o, true),
            dv.getInt16(o), dv.getInt32(o), dv.getFloat64(o)];
  }
  mg("dataview get const order", dvgc, [[DV, 0], [DV, 8]], [
    [[DV, 0], [2368, -81721024, 3.207375630676366e-192, 16393, 1074340347, 3.141592653589793], "o=0"],
    [[DV, 8], [384, -130688, 4.691977069175095e+271, -32767, -2147352833, -2.775890302926003e-309], "o=8"],
    [[DV, 3], [21755, 759452923, -9.156150349115605e+298, -1196, -78363603, -1.2054540104345729e+286], "o=3"]]);
  // Not inlined (builtin calls from Maglev code).
  function dvgu(dv, o, le) { return [dv.getUint16(o, le), dv.getUint32(o, le), dv.getFloat32(o, le)]; }
  mg("dataview get unsigned/f32", dvgu, [[DV, 8, false], [DV, 12, true]], [
    [[DV, 8, false], [32769, 2147614463, -1.8331085861065095e-40], "o=8 BE"],
    [[DV, 8, true], [384, 4294836608, NaN], "o=8 LE"],
    [[DV, 12, false], [4660, 305419896, 5.690456613903524e-28], "o=12 BE"],
    [[DV, 12, true], [13330, 2018915346, 1.7378244361449504e+34], "o=12 LE"]]);
  // Setters, unaligned (Int8/16/32/Float64 inlined, Uint16/32/Float32 builtin
  // calls); bytes read back by the interpreter.
  var SB = new ArrayBuffer(32), SDV = new DataView(SB), SU8 = new Uint8Array(SB);
  function dvs(dv, le, a, b, c, d) {
    dv.setInt8(0, a); dv.setInt16(1, b, le); dv.setInt32(3, c, le); dv.setFloat64(7, d, le);
    dv.setUint16(15, b, le); dv.setUint32(17, c, le); dv.setFloat32(21, d, le);
  }
  mg("dataview set", dvs, [[SDV, false, 1, 2, 3, 2.5], [SDV, true, 1, 2, 3, 2.5]], [
    [[SDV, false, -2, -2, 0x12345678, 1.5], [254, 255, 254, 18, 52, 86, 120, 63, 248, 0, 0, 0, 0, 0, 0,
                                             255, 254, 18, 52, 86, 120, 63, 192, 0, 0], "BE"],
    [[SDV, true, -2, -2, 0x12345678, 1.5], [254, 254, 255, 120, 86, 52, 18, 0, 0, 0, 0, 0, 0, 248, 63,
                                            254, 255, 120, 86, 52, 18, 0, 0, 192, 63], "LE"],
    [[SDV, true, 127, 0x1234, -2, -0], [127, 52, 18, 254, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 128,
                                        52, 18, 254, 255, 255, 255, 0, 0, 0, 128], "LE -0"]],
    null, {post: function () { return bytes(SU8, 25); }});
  // Native order is big-endian: i32[0] is the upper word of f64[0].
  var NB = new ArrayBuffer(16), NF64 = new Float64Array(NB), NI32 = new Int32Array(NB), NU8 = new Uint8Array(NB);
  function tnat(f64, i32, v, w) { f64[0] = v; i32[3] = w; return [f64[0], i32[3], i32[0], i32[1]]; }
  mg("typed native BE", tnat, [[NF64, NI32, 2.5, 7], [NF64, NI32, -1.25, -3]], [
    [[NF64, NI32, 1.5, -2], [[1.5, -2, 1073217536, 0],
      [63, 248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 254]], "1.5,-2"],
    [[NF64, NI32, -0, 1073741823], [[-0, 1073741823, -2147483648, 0],
      [128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 63, 255, 255, 255]], "-0,2^30-1"],
    [[NF64, NI32, NaN, 0], [[NaN, 0, 2146959360, 0],
      [127, 248, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]], "NaN,0"]],
    null, {post: function (r) { return [r, bytes(NU8, 16)]; }});
  // Holey double arrays: holes read as undefined, NaN elements stay NaN.
  var H1 = [1.5, , 3.5], H2 = [1.5, 2.5, 3.5, 4.5], H3 = [1.5, 2.5], H4 = [1.5, , NaN, 3.5];
  delete H2[1];
  H3[4] = 5.5;
  function hscan(a) {
    var holes = 0, nans = 0, sum = 0;
    for (var i = 0; i < a.length; i++) {
      var v = a[i];
      if (v === undefined) holes++;
      else if (v !== v) nans++;
      else sum += v;
    }
    return [holes, nans, sum];
  }
  mg("holey scan", hscan, [[H1], [H2], [H4]], [
    [[H1], [1, 0, 5], "[1.5,,3.5]"], [[H2], [1, 0, 9.5], "delete"],
    [[H3], [2, 0, 9.5], "grown"], [[H4], [1, 1, 5], "NaN element"]]);
  function hget(a, i) { return a[i]; }
  mg("holey load", hget, [[H1, 0], [H1, 1], [H4, 2]], [
    [[H1, 0], 1.5, "H1[0]"], [[H1, 1], undefined, "H1[1]"],
    [[H4, 2], NaN, "H4[2]"], [[H3, 3], undefined, "H3[3]"]]);
  // No holes seen: the load checks for the hole NaN and deopts on one.
  function hnh(a, i) { return a[i]; }
  mg("holey load checked", hnh, [[H1, 0], [H1, 2], [H4, 2]], [
    [[H1, 2], 3.5, "H1[2]"], [[H4, 2], NaN, "H4[2]"]],
    [["hole", [H1, 1], undefined]]);
  // A NaN with the hole's bit pattern must be silenced when stored.
  var HS = [1.5, 2.5, , 4.5], HOLE_NAN = %GetHoleNaN();
  function hst(a, i, v) { a[i] = v; }
  mg("hole-NaN store", hst, [[HS, 0, 1.25], [HS, 3, 4.75]], [
    [[HS, 0, 2.5], 2.5, "2.5"], [[HS, 1, HOLE_NAN], NaN, "over element"],
    [[HS, 2, HOLE_NAN], NaN, "into hole"]],
    null, {post: function (r, a) { return a[0][a[1]]; }});
  // charCodeAt/codePointAt: one-byte, two-byte, surrogates, fresh cons
  // strings (built at call time, not yet flattened), sliced strings.
  var L26 = "abcdefghijklmnopqrstuvwxyz", U26 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
      TB = "中文字符串测试一二三四五六七八九",
      LONG1 = "0123456789abcdefghijklmnopqrstuvwxyz",
      LONG2 = "中文字符串测试一二三四五六七八九" +
              "中文字符串测试一二三四五六七八九",
      X20 = "xxxxxxxxxxxxxxxxxxxx", Y20 = "yyyyyyyyyyyyyyyyyyyy";
  LONG2 = LONG2.split("").join("");   // flat sequential, not a cons
  function cc(s, i) { return s.charCodeAt(i); }
  mg("charCodeAt", cc, [["hello", 1], ["中文", 0], function () { return [cat(L26, U26), 2]; },
                        [LONG1.substring(5, 33), 1]], [
    [["hello", 1], 101, "one-byte"],
    [["中文", 1], 25991, "two-byte"],
    [["😀", 0], 55357, "pair hi"],
    [["😀", 1], 56832, "pair lo"],
    [function () { return [cat(L26, U26), 3]; }, 100, "cons left"],
    [function () { return [cat(L26, U26), 30]; }, 69, "cons right"],
    [function () { return [cat(TB, L26), 1]; }, 25991, "cons two-byte"],
    [function () { return [cat(TB, L26), 18]; }, 99, "cons two-byte right"],
    [[LONG1.substring(5, 33), 5], 97, "sliced"],
    [[LONG2.substring(3, 28), 0], 31526, "sliced two-byte"]]);
  function cp(s, i) { return s.codePointAt(i); }
  mg("codePointAt", cp, [["😀", 0], ["hello", 1], function () { return [cat(X20, Y20), 3]; }], [
    [["😀", 0], 128512, "pair"],
    [["😀", 1], 56832, "lone lo"],
    [["a😀b", 1], 128512, "pair inside"],
    [["中文", 0], 20013, "two-byte"],
    [["hello", 4], 111, "one-byte"],
    [function () { return [cat(X20, "😀" + Y20), 20]; }, 128512, "cons right"],
    [function () { return [cat(X20 + "\ud83d", "\ude00" + Y20), 20]; }, 128512, "pair split by cons"]]);
});

run("maglev-frames", function () {
  // Self-recursive Maglev code (Prologue with has_recursive_calls).
  function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
  mg("fib", fib, [[5], [6]], [[[2], 1], [[20], 6765]]);
  // Ten tagged values plus int32/float64 values live across a real call
  // (>= 8 tagged stack slots: the prologue's slot-fill loop).
  var O10 = {a: "a", b: "b", c: "c", d: "d", e: "e", f: "f", g: "g", h: "h", i: "i", j: "j"};
  function locals(o, n, x, f) {
    var t0 = o.a, t1 = o.b, t2 = o.c, t3 = o.d, t4 = o.e,
        t5 = o.f, t6 = o.g, t7 = o.h, t8 = o.i, t9 = o.j;
    var i0 = n + 1, i1 = n * 3, d0 = x * 0.5, d1 = x + 0.25;
    var r = f(n);
    return t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + ":" + (i0 + i1 + r) + ":" + (d0 + d1);
  }
  mg("locals across call", locals, [[O10, 3, 2.5, callee7], [O10, -2, 0.75, callee7]], [
    [[O10, 5, 1.5, callee7], "abcdefghij:56:2.5", "5,1.5"],
    [[O10, -7, -0.5, callee7], "abcdefghij:-76:-0.5", "-7,-0.5"]]);
  // OSR into Maglev at i == 10, status read in the OSR code, then an
  // eager deopt out of it (no feedback for the i == 900 branch).
  // No NeverOptimize reference: %OptimizeOsr CHECKs an optimizable function.
  function osrloop(n) {
    var s = 0, d = 0, st = 0;
    for (var i = 0; i < n; i++) {
      s += i;
      d += 0.5;
      if (i === 10) %OptimizeOsr();
      if (i === 500) st = %GetOptimizationStatus(osrloop);
      if (i === 900) s += 0.5;
    }
    return [s, d, (st & (1 << 18)) !== 0];   // kTopmostFrameIsMaglev
  }
  var o = copyOf(osrloop);
  %PrepareFunctionForOptimization(o);
  var res = o(1000);
  eq("osr frame is maglev", res[2], true);
  eq("osr result after deopt", [res[0], res[1]], [499500.5, 500]);
  // Long loop, ordinary tiering (OSR target chosen by V8).
  function hot(n) { var h = 0; for (var i = 0; i < n; i++) h = (Math.imul(h, 31) + i) | 0; return h; }
  var hc = copyOf(hot), href = copyOf(hot);
  %NeverOptimizeFunction(href);
  eqm("long loop", hc(300000), href(300000), -601855504);
  // Exceptions from a callee two frames deep caught in the Maglev frame,
  // and one thrown and caught inside it.
  function tc(n, f) {
    var s = 0, caught = 0, own = 0;
    for (var i = 0; i < n; i++) {
      try { s += f(i); } catch (e) { caught++; s += e.message.length; }
      try { if (i === n - 1) throw new TypeError("own"); } catch (e) { own += e.message.length; }
    }
    return [s, caught, own];
  }
  mg("try/catch", tc, [[5, thrower]], [[[6, thrower], [9, 3, 3]], [[2, thrower], [1, 0, 3]]]);
  // An exception unwinding through a Maglev frame without a handler.
  function pass(f, x) { var y = x * 2; return f(x) + y; }
  mg("throw through", pass, [[thrower, 1], [thrower, 2]], [
    [[thrower, 1], 3, "1"], [[thrower, 5], "threw RangeError: t5", "throws"], [[thrower, 2], 6, "2"]]);
  // ArgumentsLength / RestLength, under- and over-application.
  function argc() { var s = 0; for (var i = 0; i < arguments.length; i++) s += arguments[i]; return arguments.length * 100 + s; }
  mg("arguments", argc, [[], [1], [1, 2, 3]], [
    [[], 0], [[1], 101], [[1, 2], 203], [[1, 2, 3], 306], [[1, 2, 3, 4], 410], [[1, 2, 3, 4, 5], 515]]);
  function rest2(a, ...r) { var s = 0; for (var i = 0; i < r.length; i++) s += r[i]; return (a | 0) * 1000 + r.length * 100 + s; }
  mg("rest", rest2, [[], [1], [1, 2, 3]], [
    [[], 0], [[1], 1000], [[1, 2], 1102], [[1, 2, 3], 1205], [[1, 2, 3, 4, 5], 1414]]);
  function ov(a, b) { return (a | 0) + (b | 0) + arguments.length * 100; }
  mg("formals vs argc", ov, [[], [1], [1, 2, 3]], [
    [[], 0], [[1], 101], [[1, 2], 203], [[1, 2, 3], 303], [[1, 2, 3, 4, 5], 503]]);
  // Closures: plain context slots (3 vars), and context cells (2 vars: int32
  // state once the value leaves the Smi range, float64 state).
  function mkacc() {
    var count = 0, step = 1, hist = 0.5;
    return function acc(x) {
      count += step;
      hist = hist * 0.5 + x;
      if (count > 6) step = 2;
      return count * 1000 + hist;
    };
  }
  mg("closure slots", null, [[1], [2]], [
    [[3], 5004.578125], [[0.25], 6002.5390625], [[-1], 7000.26953125], [[4], 9004.134765625]],
    null, {make: function () { return copyOf(mkacc)(); }});
  function mkcell() {
    var a = 0, b = 0.5;
    return function cell(x) { a = (a + x) | 0; b = b * 1.5 + x; return [a, b]; };
  }
  mg("closure cells", null, [[1], [1073741823]], [
    [[5], [-2147483643, 5234491403.234375]],
    [[-3], [-2147483646, 7851737101.8515625]],
    [[1073741823], [-1073741823, 12851347475.777344]]],
    null, {make: function () { return copyOf(mkcell)(); }});
});

print("== " + (checks - failures) + "/" + checks + " checks passed" +
      (skipped.length ? " (" + skipped.length + " groups skipped: " + skipped.join(", ") + ")" : "") +
      (failures ? " — " + failures + " FAILED ==" : " — ALL PASS =="));
quit(failures ? 1 : 0);
