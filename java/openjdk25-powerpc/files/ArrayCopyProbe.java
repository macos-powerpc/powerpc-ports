import java.lang.reflect.Array;

public class ArrayCopyProbe {
    public static void main(String[] args) {
        int cases = 0;
        for (Class<?> type : new Class<?>[]{byte.class, short.class, int.class, long.class, Object.class}) {
            for (int src = 0; src < 8; src++) {
                for (int dst = 0; dst < 8; dst++) {
                    for (int count = 0; count <= 64; count++) {
                        Object values = Array.newInstance(type, 80);
                        Object[] expected = new Object[80];
                        for (int i = 0; i < 80; i++) {
                            Object value = type == byte.class ? (Object)(byte)i :
                                           type == short.class ? (Object)(short)i :
                                           type == int.class ? (Object)i :
                                           type == long.class ? (Object)(long)i : "item" + i;
                            Array.set(values, i, value);
                            expected[i] = value;
                        }
                        Object[] source = expected.clone();
                        for (int i = 0; i < count; i++) expected[dst + i] = source[src + i];
                        System.arraycopy(values, src, values, dst, count);
                        for (int i = 0; i < 80; i++) {
                            if (!expected[i].equals(Array.get(values, i))) {
                                throw new AssertionError(type + " src=" + src + " dst=" + dst + " count=" + count);
                            }
                        }
                        cases++;
                    }
                }
            }
        }
        System.out.println("Array copy overlap/zero/tail cases passed: " + cases);
    }
}
