package com.storehub.service;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class CloudinaryService {

    private final Cloudinary cloudinary;

    public String uploadImage(MultipartFile file, String folder) {
        if (file == null || file.isEmpty()) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        String contentType = file.getContentType();
        String originalFilename = file.getOriginalFilename();
        boolean isImageByExt = originalFilename != null && originalFilename.toLowerCase().matches(".*\\.(jpg|jpeg|png|webp|heic|bmp|gif)$");
        boolean isImageByMime = contentType != null && contentType.startsWith("image/");
        boolean isOctetStream = "application/octet-stream".equalsIgnoreCase(contentType);

        if (!isImageByMime && !isImageByExt && !isOctetStream) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        try {
            Map<?, ?> uploadResult = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.asMap(
                    "folder", "storehub/" + (folder != null ? folder : "general"),
                    "resource_type", "image"
            ));

            String secureUrl = (String) uploadResult.get("secure_url");
            log.info("Uploaded image to Cloudinary successfully: {}", secureUrl);
            return secureUrl;
        } catch (Exception e) {
            log.error("Failed to upload image to Cloudinary: {}", e.getMessage(), e);
            throw new AppException(ErrorCode.INTERNAL_SERVER_ERROR);
        }
    }
}
