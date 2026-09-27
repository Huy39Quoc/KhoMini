package com.storehub.mapper;

import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.entity.Booking;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

/**
 * Map Booking -> MyUnitResponse / SmartAccessResponse (Flow 3 - Thành viên 3).
 *
 * Chỉ dùng cho 2 DTO map 1-1 từ entity. ContractOperationResponse KHÔNG map
 * ở đây vì nó lắp ráp kết quả nghiệp vụ (phí tính được, ngày dự kiến, thông
 * điệp thanh toán...) chứ không phải ánh xạ trực tiếp field-to-field.
 */
@Mapper(componentModel = "spring")
public interface CustomerStorageMapper {

    @Mapping(target = "bookingId", source = "id")
    @Mapping(target = "facilityName", source = "storageUnit.facility.name", defaultValue = "Unassigned Facility")
    @Mapping(target = "facilityAddress", source = "storageUnit.facility.address", defaultValue = "")
    @Mapping(target = "unitCode", source = "storageUnit.unitCode", defaultValue = "Unassigned")
    @Mapping(target = "unitTypeName", source = "storageUnit.unitType.typeName", defaultValue = "")
    @Mapping(target = "dimensions", source = "storageUnit.unitType.dimensions", defaultValue = "")
    @Mapping(target = "areaSqm", source = "storageUnit.unitType.areaSqm")
    @Mapping(target = "activeAccess", expression = "java(booking.getStatus() == com.storehub.enums.BookingStatus.ACTIVE)")
    @Mapping(target = "hasPendingExtension", expression = "java(booking.getPendingExtraMonths() != null)")
    MyUnitResponse toMyUnitResponse(Booking booking);

    @Mapping(target = "bookingId", source = "id")
    @Mapping(target = "unitCode", source = "storageUnit.unitCode", defaultValue = "Unassigned")
    @Mapping(target = "qrCodeToken", source = "qrAccessToken")
    @Mapping(target = "locked", expression = "java(Boolean.TRUE.equals(booking.getUnitLocked()))")
    // tokenExpiresAt là quy tắc nghiệp vụ (5 phút kể từ lúc gọi API), không
    // phải dữ liệu lấy từ entity, nên tính ngay tại đây bằng expression.
    @Mapping(target = "tokenExpiresAt", expression = "java(java.time.LocalDateTime.now().plusMinutes(5))")
    SmartAccessResponse toSmartAccessResponse(Booking booking);
}
