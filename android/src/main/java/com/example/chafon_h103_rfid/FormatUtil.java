package com.example.chafon_h103_rfid;

public class FormatUtil {

    /**
     * Byte array-i HEX string formatına çevirir (məs. [0xE2, 0x80] → "E280")
     */
    public static String bytesToHexString(byte[] bytes) {
        if (bytes == null || bytes.length == 0) return "";
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }

    /**
     * HEX string-i byte array-ə çevirir (məs. "E280" → [0xE2, 0x80])
     */
    public static byte[] hexStringToBytes(String hex) {
        if (hex == null || hex.isEmpty()) return new byte[0];
        hex = hex.replaceAll("\\s", ""); // boşluqları təmizlə
        int len = hex.length();
        byte[] result = new byte[len / 2];
        for (int i = 0; i < len; i += 2) {
            result[i / 2] = (byte) ((Character.digit(hex.charAt(i), 16) << 4)
                    + Character.digit(hex.charAt(i+1), 16));
        }
        return result;
    }
}
