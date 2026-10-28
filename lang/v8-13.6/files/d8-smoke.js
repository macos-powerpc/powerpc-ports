// d8 smoke battery — v8-13.6 ppc32 Darwin port (patches 0001-0049).
// Run:  d8 d8-smoke.js
// Prints "RUN <name>" before each group so a crash identifies its site;
// PASS/FAIL per check; exits 1 if any check failed.
// Inherited from the 8.x/9.4/12.4-validated battery; group names keep their
// original patch references (the classes carried into this series):
//   toint32           — DoubleToI / TruncateDoubleToI (G3/G4 conversion class)
//   math-round        — CSA frim/frip/friz + round/popcnt op removal
//   math-fround       — fcfids removal, fcfid+frsp path
//   dataview / arrays — byte-reverse and typed-array load/store paths
//   turbofan-hot      — runtime TF codegen: Add32, imul, overflow deopt
//   wasm              — TurboFan-only (Liftoff bails out): i32 path, then
//                       Int64Lowering pair ops through the restored pair
//                       visitors, then wasm-simd must be REJECTED cleanly
//                       (SupportsWasmSimd128 false).
//   wasm-memory64     — NEW at 13.6 (memory64 ships unconditionally): a
//                       64-bit-indexed memory on a 32-bit target, memory.size
//                       returning i64 through the JS-to-wasm wrapper.
//   v8-13.6-deps      — NEW at 13.6: the paths that now go through the system
//                       simdutf (ASCII validation on string fast paths) and
//                       highway (JSON.stringify's escape scan, vector-width
//                       multiples and tails), plus a few 13.x builtins.
//   intl              — ICU i18n: Intl.*, the intl string builtins (the "tr"
//                       locale prefix compare in builtins-intl-gen.cc is the
//                       one big-endian conditional), \p{...} escapes and /iu
//                       case folding through the generated special-case
//                       tables, normalize/localeCompare.
//   microtasks        — Builtins_JSRunMicrotasksEntry (bool-ABI class)

var failures = 0, checks = 0;
function eq(name, actual, expected) {
  checks++;
  if (Object.is(actual, expected)) {
    print("PASS " + name);
  } else {
    failures++;
    print("FAIL " + name + ": got " + String(actual) + ", want " + String(expected));
  }
}
// Groups can be skipped from the command line to keep testing an installed
// build around a known process-killing failure (a CHECK aborts d8, so the
// groups after it never run):   d8 d8-smoke.js -- skip=wasm
// takes comma-separated group-name prefixes; skipped groups are not counted.
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

run("arith-basic", function () {
  eq("1+2", 1 + 2, 3);
  eq("0.1+0.2", 0.1 + 0.2, 0.30000000000000004);
  eq("5.5%2", 5.5 % 2, 1.5);
  eq("2+0.5", 2 + 0.5, 2.5);
});

run("toint32", function () {
  eq("0x123456789&0xffffffff", (0x123456789 & 0xffffffff), 591751049);
  eq("3735928559|0", 3735928559 | 0, -559038737);
  eq("(-3735928559)|0", (-3735928559) | 0, 559038737);
  eq("1e15|0", 1e15 | 0, -1530494976);
  eq("4e9>>>0", 4e9 >>> 0, 4000000000);
});

run("math-round", function () {
  eq("floor(2.5)", Math.floor(2.5), 2);
  eq("floor(-2.5)", Math.floor(-2.5), -3);
  eq("ceil(2.5)", Math.ceil(2.5), 3);
  eq("ceil(-2.5)", Math.ceil(-2.5), -2);
  eq("round(2.5)", Math.round(2.5), 3);
  eq("round(-2.5)", Math.round(-2.5), -2);
  eq("round(-0.5) is -0", Math.round(-0.5), -0);
  eq("trunc(2.9)", Math.trunc(2.9), 2);
  eq("trunc(-2.9)", Math.trunc(-2.9), -2);
  eq("clz32(1)", Math.clz32(1), 31);
});

run("math-fround", function () {
  eq("fround(1.5)", Math.fround(1.5), 1.5);
  eq("fround(2^31)", Math.fround(2147483648), 2147483648);
  eq("fround(2^24+1)", Math.fround(16777217), 16777216);
  eq("fround(4e9>>>0)", Math.fround(4e9 >>> 0), 4000000000);
});

run("math-transcendental", function () {
  eq("sqrt(2)", Math.sqrt(2), 1.4142135623730951);
  eq("sin(1)", Math.sin(1), 0.8414709848078965);
  eq("exp(1)", Math.exp(1), 2.718281828459045);
  eq("log(10)", Math.log(10), 2.302585092994046);
  eq("pow(2,3)", Math.pow(2, 3), 8);
  // 13.6: Math.pow is math::pow, which with the default
  // --use-std-math-pow calls the C library's pow (the builtin, the
  // Turboshaft and the TurboFan constant folders all go through it).
  // Darwin's libm (and glibc) return the correctly-rounded
  // 11.313708498984761 (0x1.6a09e667f3bcdp+3); the fdlibm value of
  // 8.x-12.4 (...476, 1 ulp low) now needs --no-use-std-math-pow.
  eq("pow(2,3.5)", Math.pow(2, 3.5), 11.313708498984761);
});

run("number-format", function () {
  eq("deadbeef.toString(16)", (3735928559).toString(16), "deadbeef");
  eq("parseFloat", parseFloat("1.5"), 1.5);
  eq("String(1e21)", String(1e21), "1e+21");
});

run("dataview-bytereverse", function () {
  var dv = new DataView(new ArrayBuffer(8));
  dv.setUint32(0, 0xDEADBEEF, true);            // LE store on BE = ByteRev32
  eq("getUint32 BE after LE set", dv.getUint32(0, false), 0xEFBEADDE);
  eq("getUint32 LE after LE set", dv.getUint32(0, true), 0xDEADBEEF);
  dv.setUint32(4, 0x01020304, false);
  eq("getUint32 LE after BE set", dv.getUint32(4, true), 0x04030201);
});

run("typedarray-be", function () {
  eq("Float64 BE byte0", new Uint8Array(new Float64Array([1.5]).buffer)[0], 0x3F);
  var ia = new Int32Array(1);
  ia[0] = -2;
  eq("Int32Array negative", ia[0], -2);         // LoadWordArith lwax->lwzx
  var u = new Uint32Array([4000000000]);
  eq("Uint32Array 4e9", u[0], 4000000000);
});

run("bigint-pairs", function () {
  eq("2n**64n", (2n ** 64n).toString(), "18446744073709551616");
  eq("bigint hex", (0xdeadbeefn * 0x100000000n + 0xcafebaben).toString(16),
     "deadbeefcafebabe");
});

run("string-regexp-json", function () {
  eq("regexp capture", /a(b+)c/.exec("xabbbc")[1], "bbb");
  eq("unicode length", "αβγ".length, 3);
  eq("toUpperCase", "abc".toUpperCase(), "ABC");
  eq("json roundtrip", JSON.parse(JSON.stringify({ a: [1, 2.5, "x"] })).a[1], 2.5);
});

// murmur3-32: the exact bit-mix whose collapse broke npm staging on node12.
// murmur3("test", 0) is the known vector 0xba6bd213 = 3127628307
// (same value imurmurhash('test').result() returns).
function murmur3(str, seed) {
  var h = seed | 0, k, i = 0, len = str.length;
  for (; len >= 4; len -= 4, i += 4) {
    k = (str.charCodeAt(i) & 0xff) | ((str.charCodeAt(i + 1) & 0xff) << 8) |
        ((str.charCodeAt(i + 2) & 0xff) << 16) | ((str.charCodeAt(i + 3) & 0xff) << 24);
    k = Math.imul(k, 0xcc9e2d51);
    k = (k << 15) | (k >>> 17);
    k = Math.imul(k, 0x1b873593);
    h ^= k;
    h = (h << 13) | (h >>> 19);
    h = (Math.imul(h, 5) + 0xe6546b64) | 0;
  }
  k = 0;
  switch (len) {
    case 3: k ^= (str.charCodeAt(i + 2) & 0xff) << 16;
    case 2: k ^= (str.charCodeAt(i + 1) & 0xff) << 8;
    case 1: k ^= (str.charCodeAt(i) & 0xff);
      k = Math.imul(k, 0xcc9e2d51);
      k = (k << 15) | (k >>> 17);
      k = Math.imul(k, 0x1b873593);
      h ^= k;
  }
  h ^= str.length;
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  h = Math.imul(h, 0xc2b2ae35);
  h ^= h >>> 16;
  return h >>> 0;
}

run("turbofan-hot", function () {
  // Warm everything until TurboFan kicks in, then re-check: catches bugs that
  // live only in runtime-generated optimized code (vs snapshot builtins).
  function add1(x) { return x + 1; }
  function mix(x) { return (Math.imul(x, 2654435761) ^ (x >>> 3)) >>> 0; }
  var sink = 0;
  for (var i = 0; i < 50000; i++) {
    sink ^= mix(i) ^ add1(i) ^ murmur3("k" + (i & 63), i & 7);
  }
  eq("hot murmur3('test')", murmur3("test", 0), 3127628307);
  eq("hot imul(-1,7)", Math.imul(-1, 7), -7);
  eq("hot add overflow", add1(2147483647), 2147483648);
  eq("hot mix(12345)", mix(12345), (Math.imul(12345, 2654435761) ^ (12345 >>> 3)) >>> 0);
  eq("hot fround", Math.fround(sink >>> 0), Math.fround(sink >>> 0));
});

// ---- wasm: TurboFan compiles these (Liftoff bails out on ppc32) ----
run("wasm-i32", function () {
  // (module (func (export "add") (param i32 i32) (result i32)
  //   local.get 0 local.get 1 i32.add))
  var add_bytes = new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f,
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00,
    0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b]);
  var add = new WebAssembly.Instance(new WebAssembly.Module(add_bytes)).exports.add;
  eq("wasm add(2,3)", add(2, 3), 5);
  eq("wasm add(-5,7)", add(-5, 7), 2);
  eq("wasm add wraps", add(0x7fffffff, 1), -2147483648);
  // Warm the js-to-wasm call path; self-checked against pure JS.
  var s = 0, t = 0;
  for (var i = 0; i < 20000; i++) { s = (s + add(s, i)) | 0; }
  for (var j = 0; j < 20000; j++) { t = (t + ((t + j) | 0)) | 0; }
  eq("wasm add warm", s, t);
});

run("wasm-i64-pairs", function () {
  // (module (func (export "mul64") (param i64 i64) (result i64)
  //   local.get 0 local.get 1 i64.mul))
  // i64 wasm ops become Word32 pair ops via Int64Lowering on ppc32; the
  // full-width products cross the register-pair boundary.
  var mul_bytes = new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x07, 0x01, 0x60, 0x02, 0x7e, 0x7e, 0x01, 0x7e,
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x09, 0x01, 0x05, 0x6d, 0x75, 0x6c, 0x36, 0x34, 0x00, 0x00,
    0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x7e, 0x0b]);
  var mul64 = new WebAssembly.Instance(new WebAssembly.Module(mul_bytes)).exports.mul64;
  eq("wasm mul64 cross-half", mul64(0x100000001n, 3n), 0x300000003n);
  eq("wasm mul64 signs", mul64(-1n, -1n), 1n);
  eq("wasm mul64 shifted", mul64(0xdeadbeefn, 0x1000n), 0xdeadbeef000n);
});

run("wasm-simd-reject", function () {
  // (module (func (export "s") (result i32)
  //   v128.const i32x4 0 0 0 0  i32x4.extract_lane 0))
  // SupportsWasmSimd128() is false on this target: the module must be
  // rejected as unsupported (validate false or CompileError), never
  // compiled — reaching the compiled-out F64x2/SIMD codegen would crash.
  var simd_bytes = new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x05, 0x01, 0x01, 0x73, 0x00, 0x00,
    0x0a, 0x19, 0x01, 0x17, 0x00, 0xfd, 0x0c, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0xfd, 0x1b, 0x00, 0x0b]);
  var rejected = !WebAssembly.validate(simd_bytes);
  if (!rejected) {
    try { new WebAssembly.Module(simd_bytes); }
    catch (e) { rejected = (e instanceof WebAssembly.CompileError); }
  }
  checks++;
  if (rejected) {
    print("PASS wasm simd rejected");
  } else {
    failures++;
    print("FAIL wasm simd was accepted — SupportsWasmSimd128 must be false here");
  }
});

run("wasm-memory64", function () {
  // (module (memory i64 1) (func (export "size") (result i64) memory.size))
  // memory64 shipped unconditionally at 13.6: a 64-bit-indexed memory on a
  // 32-bit target; memory.size returns i64 (1n for one page) through the
  // JS-to-wasm wrapper's BigInt conversion.
  var m64_bytes = new Uint8Array([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e,
    0x03, 0x02, 0x01, 0x00,
    0x05, 0x03, 0x01, 0x04, 0x01,
    0x07, 0x08, 0x01, 0x04, 0x73, 0x69, 0x7a, 0x65, 0x00, 0x00,
    0x0a, 0x06, 0x01, 0x04, 0x00, 0x3f, 0x00, 0x0b]);
  eq("memory64 validates", WebAssembly.validate(m64_bytes), true);
  var size = new WebAssembly.Instance(new WebAssembly.Module(m64_bytes)).exports.size;
  eq("memory64 memory.size", size(), 1n);
});

run("v8-13.6-deps", function () {
  // simdutf: String::IsAscii / Utf8::IsAsciiOneByteString on the string
  // fast paths (concatenation flattening, one-byte checks) and on
  // TextEncoder-less d8 through JSON/regexp; exercise lengths across the
  // vector widths and a non-ASCII tail.
  var ascii = "", i;
  for (i = 0; i < 100; i++) ascii += String.fromCharCode(32 + (i % 90));
  eq("ascii flatten length", (ascii + ascii).length, 200);
  eq("ascii charCode", (ascii + "!").charCodeAt(100), 33);
  eq("one-byte with high tail", (ascii + "\u00e9").length, 101);
  eq("isWellFormed", "ab\ud800".isWellFormed(), false);
  eq("toWellFormed", "ab\ud800".toWellFormed().charCodeAt(2), 0xfffd);
  // highway: JSON.stringify's escape scan runs over the string in vector
  // chunks; check clean strings of 15/16/17/64/65 chars and escapes at
  // the chunk boundary and in the tail.
  var s15 = "abcdefghijklmno", s16 = s15 + "p", s17 = s16 + "q";
  eq("json 15", JSON.stringify(s15), '"' + s15 + '"');
  eq("json 16", JSON.stringify(s16), '"' + s16 + '"');
  eq("json 17", JSON.stringify(s17), '"' + s17 + '"');
  var s64 = s16 + s16 + s16 + s16;
  eq("json 64", JSON.stringify(s64).length, 66);
  eq("json 65 with tail quote", JSON.stringify(s64 + '"'), '"' + s64 + '\\""');
  eq("json escape at 16", JSON.stringify(s16 + "\n" + s16), '"' + s16 + "\\n" + s16 + '"');
  eq("json control char", JSON.stringify("a\u0001b"), '"a\\u0001b"');
  eq("json non-ascii passthrough", JSON.stringify("\u00e9\u4e2d"), '"\u00e9\u4e2d"');
  eq("json object", JSON.stringify({k: [1, "x\ty", null, true]}), '{"k":[1,"x\\ty",null,true]}');
  // a few 13.x-era builtins (CSA/Torque paths through the new snapshot)
  eq("toSorted", [3, 1, 2].toSorted().join(), "1,2,3");
  eq("Object.groupBy", Object.groupBy([1, 2, 3, 4], function (x) { return x % 2 ? "odd" : "even"; }).odd.join(), "1,3");
  eq("Set.union", new Set([1, 2]).union(new Set([2, 3])).size, 3);
  eq("iterator helpers", [1, 2, 3, 4].values().map(function (x) { return x * 2; }).take(2).toArray().join(), "2,4");
  eq("Promise.withResolvers", typeof Promise.withResolvers().resolve, "function");
  eq("regexp v flag", /[\p{L}--[a-z]]/v.test("A"), true);
  eq("Array.fromAsync exists", typeof Array.fromAsync, "function");
});

run("intl", function () {
  eq("Intl present", typeof Intl, "object");
  eq("NumberFormat en-US", new Intl.NumberFormat("en-US").format(1234567.891), "1,234,567.891");
  eq("NumberFormat BigInt", new Intl.NumberFormat("en-US").format(12345678901234567890n),
     "12,345,678,901,234,567,890");
  eq("DateTimeFormat UTC",
     new Intl.DateTimeFormat("en-US", {timeZone: "UTC", year: "numeric", month: "2-digit", day: "2-digit"})
       .format(new Date(Date.UTC(2020, 0, 2))), "01/02/2020");
  eq("PluralRules en", new Intl.PluralRules("en").select(1) + "/" + new Intl.PluralRules("en").select(2), "one/other");
  eq("ListFormat en", new Intl.ListFormat("en", {style: "long", type: "conjunction"}).format(["a", "b", "c"]),
     "a, b, and c");
  eq("Segmenter words", Array.from(new Intl.Segmenter("en", {granularity: "word"}).segment("hello world")).length, 3);
  eq("getCanonicalLocales", Intl.getCanonicalLocales("EN-us")[0], "en-US");
  eq("Collator numeric", new Intl.Collator("en", {numeric: true}).compare("2", "10"), -1);
  // String builtins routed through ICU (builtins-intl-gen.cc / runtime-intl.cc).
  eq("toLowerCase ascii fast path", "HeLLo".toLowerCase(), "hello");
  eq("toUpperCase sharp s", "stra\u00dfe".toUpperCase(), "STRASSE");
  // The BE-conditional 2-byte locale prefix compare: "tr" must be detected
  // and take the locale-sensitive runtime path (dotless i), "en" must not.
  eq("toLocaleLowerCase tr", "I".toLocaleLowerCase("tr"), "\u0131");
  eq("toLocaleLowerCase en", "I".toLocaleLowerCase("en"), "i");
  eq("normalize NFD", "\u00c5".normalize("NFD").length, 2);
  eq("normalize NFC", "A\u030a".normalize("NFC"), "\u00c5");
  eq("localeCompare a<B", "a".localeCompare("B"), -1);
  // Unicode property escapes and /iu canonicalization (special-case.cc).
  eq("\\p{Lu} A", /\p{Lu}/u.test("A"), true);
  eq("\\p{Lu} a", /\p{Lu}/u.test("a"), false);
  eq("\\p{Script=Greek}", /^\p{Script=Greek}+$/u.test("\u03b1\u03b2\u03b3"), true);
  eq("/iu long s folds to s", /\u017f/iu.test("s"), true);
  eq("/i long s does not", /\u017f/i.test("s"), false);
  eq("/iu kelvin sign folds to k", /k/iu.test("\u212a"), true);
});

// ---- microtasks last: everything below runs through JSRunMicrotasksEntry ----
var order = [];
print("RUN  microtasks-async (draining via Builtins_JSRunMicrotasksEntry now)");
order.push("sync1");
Promise.resolve("p").then(function (v) { order.push(v + "1"); })
                    .then(function () { order.push("p2"); });
(async function () {
  var v = await Promise.resolve(1);
  v += await new Promise(function (r) { r(2); });
  order.push("async" + (v + 39));                // async42
})().then(function () {
  order.push("done");
  eq("microtask order", order.join(","), "sync1,sync2,p1,p2,async42,done");
  print("== " + (checks - failures) + "/" + checks + " checks passed" +
        (skipped.length ? " (" + skipped.length + " groups skipped: " + skipped.join(", ") + ")" : "") +
        (failures ? " — " + failures + " FAILED ==" : " — ALL PASS ==" ));
  quit(failures ? 1 : 0);
});
order.push("sync2");
print("== sync checks done; if it dies past this line, microtask entry is the culprit ==");
