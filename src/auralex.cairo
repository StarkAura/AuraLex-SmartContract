#[starknet::contract]
pub mod Auralex {
    use auralex_contracts::base::types::{CourseDetails, ResourceType};
    use auralex_contracts::interfaces::IAuralex::IAuralex;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp};

    #[storage]
    struct Storage {
        // Course management
        courses: Map<u256, CourseDetails>,
        next_course_id: u256,
    }


    #[abi(embed_v0)]
    impl AuralexImpl of IAuralex<ContractState> {
        fn create_course(
            ref self: ContractState, name: ByteArray, instructor: ContractAddress, enroll_fee: u256,
        ) -> u256 {
            // Get the current course ID
            let id = self.next_course_id.read() + 1; // Use it before incrementing
            let timestamp = get_block_timestamp();

            let mut course_type = ResourceType::Paid;
            if (enroll_fee == 0) {
                course_type = ResourceType::Free;
            }
            // Create a new course struct
            let new_course = CourseDetails {
                course_id: id,
                name,
                instructor,
                total_enrolled: 0,
                course_type: course_type,
                enroll_fee,
                updated_at: timestamp,
                created_at: timestamp,
            };

            // Store the course in the courses map
            self.courses.write(id, new_course);

            // Increment course ID and update storage **after** using it
            self.next_course_id.write(id);

            id
        }


        fn get_course(self: @ContractState, course_id: u256) -> CourseDetails {
            // Retrieve and return the course
            let course = self.courses.read(course_id);

            course
        }
    }
}
