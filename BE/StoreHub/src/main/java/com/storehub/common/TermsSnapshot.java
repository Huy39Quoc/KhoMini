package com.storehub.common;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class TermsSnapshot {
    private TermsSnapshot() {}

    public static String hash(String version, String terms, String prohibitedItems) {
        if (version == null || version.isBlank() || terms == null || terms.isBlank()
                || prohibitedItems == null || prohibitedItems.isBlank()) return null;
        // Length prefixes make the three exact text values unambiguous.
        String content = version.length() + ":" + version + terms.length() + ":" + terms
                + prohibitedItems.length() + ":" + prohibitedItems;
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(content.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is required", ex);
        }
    }
}
