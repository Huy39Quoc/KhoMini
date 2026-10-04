package com.storehub.service;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.ResetPinRequest;
import com.storehub.dto.request.SetupPinRequest;
import com.storehub.dto.request.UnlockRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.dto.response.SmartAccessResponse;

import java.util.List;
import java.util.UUID;

public interface CustomerStorageService {
    List<MyUnitResponse> getMyRentedUnits(String customerEmail);

    SmartAccessResponse getSmartAccessInfo(UUID bookingId, String customerEmail);

    // Tạo PIN lần đầu: hệ thống cấp (newPin trống) hoặc khách tự đặt.
    SmartAccessResponse setupPin(UUID bookingId, String customerEmail, SetupPinRequest request);

    // Đổi PIN: phải nhập đúng PIN hiện tại.
    SmartAccessResponse updateAccessPin(UUID bookingId, String customerEmail, UpdatePinRequest request);

    // Quên PIN: xác minh bằng mật khẩu tài khoản rồi cấp/đặt PIN mới.
    SmartAccessResponse resetPin(UUID bookingId, String customerEmail, ResetPinRequest request);

    // Mở khóa ngăn kho - bắt buộc nhập đúng PIN (mô phỏng, không có phần cứng thật).
    SmartAccessResponse unlockWithPin(UUID bookingId, String customerEmail, UnlockRequest request);

    // Đóng khóa lại (không cần PIN). locked=false không được dùng, mở khóa phải qua unlockWithPin.
    SmartAccessResponse setLockState(UUID bookingId, String customerEmail, boolean locked);

    ContractOperationResponse extendRental(UUID bookingId, String customerEmail, ExtendRentalRequest request);

    ContractOperationResponse requestCheckout(UUID bookingId, String customerEmail, CheckoutRequest request);

    ContractOperationResponse cancelPendingExtension(UUID bookingId, String customerEmail);

    PaymentResponse getPendingExtensionPayment(UUID bookingId, String customerEmail);
}