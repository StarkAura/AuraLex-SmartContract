#[starknet::contract]
pub mod Auralex {
    use auralex_contracts::base::types::{CourseDetails, ResourceType};
    use auralex_contracts::interfaces::IAuralex::IAuralex;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    struct Storage {
        // Course management
        courses: Map<u256, CourseDetails>,
        next_course_id: u256,
        // Course enrollments: course_id -> (student_address -> bool)
        course_enrollments: Map<(u256, ContractAddress), bool>,
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

        fn enroll_for_course(ref self: ContractState, course_id: u256, fee: u256) {
            // Get the caller address
            let caller = get_caller_address();

            // Check if course_id is within valid range
            let next_id = self.next_course_id.read();
            assert(course_id > 0 && course_id <= next_id, 'Course does not exist');

            // Retrieve the course details
            let mut course = self.courses.read(course_id);

            // Validate that the course exists (course_id should be > 0)
            assert(course.course_id != 0, 'Course does not exist');

            // Check if student is already enrolled
            let is_enrolled = self.course_enrollments.read((course_id, caller));
            assert(!is_enrolled, 'Already enrolled in course');

            // Validate fee for the course type
            if course.course_type == ResourceType::Free {
                assert(fee == 0, 'Free course requires no fee');
                assert(course.enroll_fee == 0, 'Course fee mismatch');
            } else {
                // For paid courses, validate the fee matches
                assert(fee == course.enroll_fee, 'Incorrect enrollment fee');
                assert(fee > 0, 'Paid course requires fee');
                // In a real implementation, you would:
            // 1. Transfer tokens from caller to contract/instructor using ERC20
            // 2. Handle the actual payment logic here
            // For now, we just validate the fee amount
            }

            // Mark student as enrolled
            self.course_enrollments.write((course_id, caller), true);

            // Increment the total enrolled count
            course.total_enrolled += 1;
            course.updated_at = get_block_timestamp();

            // Update the course in storage
            self.courses.write(course_id, course);
        }
        fn is_enrolled(self: @ContractState, course_id: u256, student: ContractAddress) -> bool {
            self.course_enrollments.read((course_id, student))
        }
    }
}
