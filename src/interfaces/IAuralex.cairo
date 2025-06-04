use starknet::ContractAddress;
use crate::base::types::{Certificate, CourseDetails};

#[starknet::interface]
pub trait IAuralex<TContractState> {
    // Courses
    fn create_course(
        ref self: TContractState, name: ByteArray, instructor: ContractAddress, enroll_fee: u256,
    ) -> u256;
    fn get_course(self: @TContractState, course_id: u256) -> CourseDetails;
    fn enroll_for_course(ref self: TContractState, course_id: u256, fee: u256);
    fn is_enrolled(self: @TContractState, course_id: u256, student: ContractAddress) -> bool;

    // Payment token management
    fn get_payment_token(self: @TContractState) -> ContractAddress;
    fn set_payment_token(ref self: TContractState, new_token_address: ContractAddress);
    fn issue_certificate(
        ref self: TContractState,
        course_id: u256,
        student: ContractAddress,
        metadata_uri: ByteArray,
    ) -> u256;
    fn get_certificate(self: @TContractState, certificate_id: u256) -> Certificate;
    fn mint_certificate_on_completion(
        ref self: TContractState,
        course_id: u256,
        student: ContractAddress,
        metadata_uri: ByteArray,
    ) -> u256;
    fn is_course_completed(
        self: @TContractState, course_id: u256, student: ContractAddress,
    ) -> bool;
    // fn mint_course_certificate(ref self: TContractState, course_id: u256);
// fn verify_course_credential(self: @TContractState, course_id: u256, student:
// ContractAddress);
}
