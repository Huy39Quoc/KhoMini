package com.storehub.service;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.BookingResponse;
import com.storehub.dto.response.RentalQuoteResponse;

public interface BookingService {

    /**
     * Tạo đơn đặt chỗ kho mới.
     * Tự động chọn 1 unit khả dụng (AVAILABLE) theo facility + unitType,
     * tính toán giá thuê và tạo booking với trạng thái PENDING_PAYMENT.
     *
     * @param customerEmail email của khách hàng (lấy từ JWT)
     * @param request       thông tin đặt chỗ
     * @return chi tiết booking vừa tạo
     */
    BookingResponse createBooking(String customerEmail, BookingCreationRequest request);

    /**
     * Tính báo giá nhanh mà không tạo booking.
     * Dùng để hiển thị trước cho khách xác nhận.
     *
     * @param request thông tin báo giá
     * @return bảng kê chi tiết chi phí
     */
    RentalQuoteResponse getRentalQuote(RentalQuoteRequest request);
}
