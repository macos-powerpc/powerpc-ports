import sun.misc.Unsafe;
import java.lang.reflect.Field;

public class ByteReverseProbe {
    static final Unsafe U;
    static final long BASE;
    static volatile long input;
    static {
        try {
            Field field = Unsafe.class.getDeclaredField("theUnsafe");
            field.setAccessible(true);
            U = (Unsafe)field.get(null);
            BASE = U.arrayBaseOffset(long[].class);
        } catch (ReflectiveOperationException e) { throw new ExceptionInInitializerError(e); }
    }
    static long load(long address) { return Long.reverseBytes(U.getLong(address)); }
    static long acquire(long[] array) { return Long.reverseBytes(U.getLongVolatile(array, BASE)); }
    static void store(long address, long value) { U.putLong(address, Long.reverseBytes(value)); }
    static void release(long[] array, long value) { U.putLongVolatile(array, BASE, Long.reverseBytes(value)); }
    static long expected(long value) {
        long result = 0;
        for (int i = 0; i < 8; ++i) { result = (result << 8) | (value & 255); value >>>= 8; }
        return result;
    }
    public static void main(String[] args) {
        long address = U.allocateMemory(16);
        long[] array = new long[1];
        long value = 0x0123456789abcdefL;
        try {
            for (int i = 0; i < 100000; ++i) {
                input = value;
                long reversed = expected(input);
                U.putLong(address, input);
                if (load(address) != reversed) throw new AssertionError("reversed load");
                U.putLongVolatile(array, BASE, input);
                if (acquire(array) != reversed) throw new AssertionError("reversed acquire");
                store(address, input);
                if (U.getLong(address) != reversed) throw new AssertionError("reversed store");
                release(array, input);
                if (U.getLongVolatile(array, BASE) != reversed) throw new AssertionError("reversed release");
                value = value * 6364136223846793005L + 1442695040888963407L;
            }
        } finally { U.freeMemory(address); }
        System.out.println("PASS 100000 compiled reversed loads, acquire loads, stores and release stores");
    }
}
