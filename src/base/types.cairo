use core::option::OptionTrait;
use core::serde::Serde;
use core::starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct CourseDetails {
    pub course_id: u256,
    pub name: ByteArray,
    pub instructor: ContractAddress,
    pub total_enrolled: u256,
    pub course_type: ResourceType,
    pub enroll_fee: u256,
}

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct CertificateDetails {
    pub certification_id: u256,
    pub name: ByteArray,
    pub institution: ContractAddress,
    pub total_enrolled: u256,
    pub certification_type: ResourceType,
    pub enroll_fee: u256,
}


#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum ResourceType {
    Free,
    Paid,
}
