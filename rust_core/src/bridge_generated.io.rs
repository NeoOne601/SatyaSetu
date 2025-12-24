use super::*;
// Section: wire functions

#[no_mangle]
pub extern "C" fn wire_rust_init_core(port_: i64) {
    wire_rust_init_core_impl(port_)
}

#[no_mangle]
pub extern "C" fn wire_rust_reset_vault(port_: i64, storage_path: *mut wire_uint_8_list) {
    wire_rust_reset_vault_impl(port_, storage_path)
}

#[no_mangle]
pub extern "C" fn wire_rust_initialize_vault(
    port_: i64,
    pin: *mut wire_uint_8_list,
    hw_id: *mut wire_uint_8_list,
    storage_path: *mut wire_uint_8_list,
) {
    wire_rust_initialize_vault_impl(port_, pin, hw_id, storage_path)
}

#[no_mangle]
pub extern "C" fn wire_rust_create_identity(port_: i64, label: *mut wire_uint_8_list) {
    wire_rust_create_identity_impl(port_, label)
}

#[no_mangle]
pub extern "C" fn wire_rust_sign_intent(
    port_: i64,
    identity_id: *mut wire_uint_8_list,
    upi_url: *mut wire_uint_8_list,
) {
    wire_rust_sign_intent_impl(port_, identity_id, upi_url)
}

#[no_mangle]
pub extern "C" fn wire_rust_publish_to_nostr(port_: i64, signed_json: *mut wire_uint_8_list) {
    wire_rust_publish_to_nostr_impl(port_, signed_json)
}

#[no_mangle]
pub extern "C" fn wire_rust_get_identities(port_: i64) {
    wire_rust_get_identities_impl(port_)
}

#[no_mangle]
pub extern "C" fn wire_rust_scan_qr(port_: i64, raw_qr_string: *mut wire_uint_8_list) {
    wire_rust_scan_qr_impl(port_, raw_qr_string)
}

// Section: allocate functions

#[no_mangle]
pub extern "C" fn new_uint_8_list_0(len: i32) -> *mut wire_uint_8_list {
    let ans = wire_uint_8_list {
        ptr: support::new_leak_vec_ptr(Default::default(), len),
        len,
    };
    support::new_leak_box_ptr(ans)
}

// Section: related functions

// Section: impl Wire2Api

impl Wire2Api<String> for *mut wire_uint_8_list {
    fn wire2api(self) -> String {
        let vec: Vec<u8> = self.wire2api();
        String::from_utf8_lossy(&vec).into_owned()
    }
}

impl Wire2Api<Vec<u8>> for *mut wire_uint_8_list {
    fn wire2api(self) -> Vec<u8> {
        unsafe {
            let wrap = support::box_from_leak_ptr(self);
            support::vec_from_leak_ptr(wrap.ptr, wrap.len)
        }
    }
}
// Section: wire structs

#[repr(C)]
#[derive(Clone)]
pub struct wire_uint_8_list {
    ptr: *mut u8,
    len: i32,
}

// Section: impl NewWithNullPtr

pub trait NewWithNullPtr {
    fn new_with_null_ptr() -> Self;
}

impl<T> NewWithNullPtr for *mut T {
    fn new_with_null_ptr() -> Self {
        std::ptr::null_mut()
    }
}

// Section: sync execution mode utility

#[no_mangle]
pub extern "C" fn free_WireSyncReturn(ptr: support::WireSyncReturn) {
    unsafe {
        let _ = support::box_from_leak_ptr(ptr);
    };
}
