import java.util.*;

public class Java25Bringup {
    public static void main(String[] args) throws Exception {
        if (Runtime.version().feature() != 25) throw new AssertionError("Runtime version");
        ScopedValue<String> value = ScopedValue.newInstance();
        ScopedValue.where(value, "PowerPC Java 25").run(() -> {
            if (!value.get().equals("PowerPC Java 25")) throw new AssertionError("ScopedValue");
        });
        if (value.isBound()) throw new AssertionError("Leaked scope");
        SequencedCollection<Integer> items = new ArrayList<>(List.of(1, 2, 3));
        if (items.reversed().getFirst() != 3 || items.getLast() != 3)
            throw new AssertionError("SequencedCollection");
        var virtualResult = new java.util.concurrent.atomic.AtomicBoolean();
        Thread virtual = Thread.ofVirtual().start(() ->
            virtualResult.set(Thread.currentThread().isVirtual()));
        virtual.join();
        if (!virtualResult.get()) throw new AssertionError("Virtual thread");
        Object record = new Point(3, 4);
        int sum = switch (record) {
            case Point(int x, int y) -> x + y;
            default -> 0;
        };
        if (sum != 7) throw new AssertionError("Record pattern");
        var source = java.nio.file.Files.createTempFile("jdk25-source", ".txt");
        var target = source.resolveSibling(source.getFileName() + ".copy");
        try {
            java.nio.file.Files.writeString(source, "PowerPC file copy");
            var birth = java.nio.file.attribute.FileTime.fromMillis(1600000000000L);
            java.nio.file.Files.getFileAttributeView(source,
                java.nio.file.attribute.BasicFileAttributeView.class).setTimes(null, null, birth);
            var actual = java.nio.file.Files.readAttributes(source,
                java.nio.file.attribute.BasicFileAttributes.class).creationTime();
            if (Math.abs(actual.toMillis() - birth.toMillis()) > 2000)
                throw new AssertionError("creation time: " + actual);
            java.nio.file.Files.copy(source, target, java.nio.file.StandardCopyOption.COPY_ATTRIBUTES);
            if (!java.nio.file.Files.readString(target).equals("PowerPC file copy"))
                throw new AssertionError("copy fallback");
        } finally {
            java.nio.file.Files.deleteIfExists(target);
            java.nio.file.Files.deleteIfExists(source);
        }
        System.out.println("PASS Java 25 runtime, ScopedValue, sequenced collections, virtual threads, record patterns and file attributes");
    }
    record Point(int x, int y) {}
}
