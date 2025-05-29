use starknet::ContractAddress;
use crate::base::types::CourseDetails;
#[starknet::interface]
pub trait IAuralex<TContractState> {
    // Courses
    fn create_course(
        ref self: TContractState, name: ByteArray, instructor: ContractAddress, enroll_fee: u256,
    ) -> u256;
    fn get_course(self: @TContractState, course_id: u256) -> CourseDetails;
    // fn enroll_for_course(ref self: TContractState, course_id: u256, fee: u256);
// fn mint_course_certificate(ref self: TContractState, course_id: u256);
// fn verify_course_credential(self: @TContractState, course_id: u256, student:
// ContractAddress);
}
