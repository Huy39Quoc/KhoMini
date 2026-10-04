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
    @Mapping(target = "activeAccess", expression = "java(booking.getStatus() == com.storehub.enums.BookingStatus.ACTIVE && booking.getAccessDisabledAt() == null)")
    @Mapping(target = "accessDisabled", expression = "java(booking.getAccessDisabledAt() != null)")
    @Mapping(target = "overdue", expression = "java(booking.getOverdueDetectedAt() != null)")
    @Mapping(target = "overdueDays", ignore = true)
    @Mapping(target = "overdueFeeOutstanding", ignore = true)
    @Mapping(target = "scheduledReturnTime", source = "returnTime")
    @Mapping(target = "hasPendingExtension", expression = "java(booking.getPendingExtraMonths() != null)")
    MyUnitResponse toMyUnitResponse(Booking booking);

    @Mapping(target = "bookingId", source = "id")
    @Mapping(target = "unitCode", source = "storageUnit.unitCode", defaultValue = "Unassigned")
    @Mapping(target = "locked", expression = "java(Boolean.TRUE.equals(booking.getUnitLocked()))")
    @Mapping(target = "pinSet", expression = "java(booking.getAccessPin() != null && !booking.getAccessPin().isBlank())")
    @Mapping(target = "pinLockedUntil", expression = "java(booking.getPinLockedUntil() != null && booking.getPinLockedUntil().isAfter(java.time.LocalDateTime.now()) ? booking.getPinLockedUntil() : null)")
    @Mapping(target = "attemptsRemaining", ignore = true)
    @Mapping(target = "generatedPin", ignore = true)
    SmartAccessResponse toSmartAccessResponse(Booking booking);
}
