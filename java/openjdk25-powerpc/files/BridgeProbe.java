import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;

public class BridgeProbe {
    public static void main(String[] args) {
        BufferedImage image = new BufferedImage(128, 64, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = image.createGraphics();
        graphics.setColor(Color.WHITE);
        graphics.fillRect(0, 0, 128, 64);
        graphics.setColor(Color.BLACK);
        graphics.setFont(new Font("Dialog", Font.PLAIN, 14));
        graphics.drawString("PowerPC Java 25", 4, 24);
        if (graphics.getFontMetrics().stringWidth("PowerPC") <= 0) {
            throw new AssertionError("font metrics");
        }
        graphics.dispose();
        int ink = 0;
        for (int y = 0; y < 64; y++) {
            for (int x = 0; x < 128; x++) {
                if (image.getRGB(x, y) != 0xffffffff) ink++;
            }
        }
        if (ink == 0) throw new AssertionError("empty text");
        System.out.println("desktop bridge PASS ink=" + ink);
    }
}
