## ADDED Requirements

### Requirement: Employee options are independent of leave-order results
The leave-order screen SHALL populate its employee selector from the authorized employee directory rather than from leave orders returned for the selected payroll cycle. The selector SHALL include every employee returned across all directory pages, including employees with no orders in the selected cycle.

#### Scenario: Employee without orders remains selectable
- **WHEN** an employee exists in the employee directory but has no leave, OT, or WFH order in the selected payroll cycle
- **THEN** the employee SHALL still appear in the employee selector

#### Scenario: Directory contains multiple pages
- **WHEN** the employee directory response indicates that additional pages exist
- **THEN** the screen SHALL load the additional pages before treating the selector as complete

#### Scenario: Directory includes an inactive employee
- **WHEN** the authorized employee directory returns an inactive or former employee
- **THEN** the selector SHALL retain that employee so HR can review historical payroll cycles

### Requirement: Employee selection uses stable user identity
The system SHALL represent the selected employee by user ID and SHALL send that ID as the `user_id` leave-order filter. Employee names SHALL be display labels only.

#### Scenario: Duplicate employee names
- **WHEN** two employees have the same display name and HR selects one of them
- **THEN** the system SHALL filter orders using the selected employee's user ID without including the other employee's orders

#### Scenario: Selected employee has no matching orders
- **WHEN** HR selects an employee who has no orders matching the current month, status, or type filters
- **THEN** the order list SHALL show its empty state while the selected employee remains selected

### Requirement: Employee options remain stable while filtering
Changing the selected employee, payroll month, order status, or order type SHALL NOT rebuild or narrow the employee options from the filtered order list.

#### Scenario: Selecting an employee does not collapse options
- **WHEN** HR selects an employee and reopens the employee selector
- **THEN** the selector SHALL still contain all employees loaded from the directory

#### Scenario: Order filters change
- **WHEN** HR changes the order status or order type filter
- **THEN** the selected employee and the complete employee option set SHALL be preserved

#### Scenario: Payroll month changes
- **WHEN** HR changes the payroll month while an employee is selected
- **THEN** the same employee SHALL remain selected and the system SHALL refresh that employee's orders for the new payroll cycle

### Requirement: All-employees selection clears the employee filter
The selector SHALL provide an "All employees" option that clears the selected user ID without mutating the directory-backed employee options.

#### Scenario: Return to all employees
- **WHEN** HR selects "All employees"
- **THEN** the system SHALL omit the `user_id` filter, show orders for all employees permitted by the current filters, and retain the complete selector options

