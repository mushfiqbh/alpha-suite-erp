# Database Schema

## Enum Types

### `user_role`
| Value        |
|--------------|
| `admin`      |
| `operations` |
| `sales`      |
| `hr`         |
| `viewer`     |

---

## Tables

### `profiles`
Linked to `auth.users`. Created automatically via trigger on sign-up.

| Column       | Type                        | Constraints                          |
|--------------|-----------------------------|--------------------------------------|
| `id`         | `UUID`                      | PK → `auth.users(id) ON DELETE CASCADE` |
| `email`      | `TEXT`                      |                                      |
| `full_name`  | `TEXT`                      | `NOT NULL`                           |
| `role`       | `user_role`                 | `NOT NULL DEFAULT 'viewer'`          |
| `phone`      | `TEXT`                      |                                      |
| `avatar_url` | `TEXT`                      |                                      |
| `is_active`  | `BOOLEAN`                   | `DEFAULT TRUE`                       |
| `created_at` | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at` | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** None beyond PK.

**RLS:** Users read/update own profile; admins read all.

---

### `customers`

| Column            | Type                        | Constraints                          |
|-------------------|-----------------------------|--------------------------------------|
| `id`              | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `customer_code`   | `VARCHAR(20)`               | `NOT NULL UNIQUE`                    |
| `customer_type`   | `VARCHAR(20)`               | `NOT NULL DEFAULT 'company'`         |
| `company_name`    | `VARCHAR(255)`              |                                      |
| `first_name`      | `VARCHAR(100)`              |                                      |
| `last_name`       | `VARCHAR(100)`              |                                      |
| `email`           | `VARCHAR(255)`              |                                      |
| `phone`           | `VARCHAR(50)`               |                                      |
| `website`         | `VARCHAR(255)`              |                                      |
| `industry`        | `VARCHAR(100)`              |                                      |
| `billing_address` | `TEXT`                      |                                      |
| `shipping_address`| `TEXT`                      |                                      |
| `city`            | `VARCHAR(100)`              |                                      |
| `country`         | `VARCHAR(100)`              |                                      |
| `status`          | `VARCHAR(20)`               | `NOT NULL DEFAULT 'prospect'` — check: `active`, `inactive`, `prospect`, `lead`, `customer`, `vip` |
| `source`          | `VARCHAR(50)`               |                                      |
| `assigned_to`     | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |
| `created_at`      | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at`      | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `created_by`      | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |

**RLS:** Users with `admin`, `operations`, or `sales` roles can CRUD.

---

### `products`

| Column         | Type                        | Constraints                          |
|----------------|-----------------------------|--------------------------------------|
| `id`           | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `sku`          | `VARCHAR(40)`               | `NOT NULL UNIQUE`                    |
| `name`         | `VARCHAR(255)`              | `NOT NULL`                           |
| `description`  | `TEXT`                      |                                      |
| `category`     | `VARCHAR(100)`              |                                      |
| `unit`         | `VARCHAR(40)`               | `DEFAULT 'pcs'`                      |
| `price`        | `NUMERIC(12,2)`             | `NOT NULL DEFAULT 0` — `>= 0`        |
| `cost`         | `NUMERIC(12,2)`             | `NOT NULL DEFAULT 0` — `>= 0`        |
| `stock`        | `INTEGER`                   | `NOT NULL DEFAULT 0` — `>= 0`        |
| `reorder_level`| `INTEGER`                   | `NOT NULL DEFAULT 0`                 |
| `status`       | `VARCHAR(20)`               | `NOT NULL DEFAULT 'active'` — check: `active`, `inactive`, `draft`, `archived`, `out_of_stock` |
| `barcode`      | `VARCHAR(80)`               |                                      |
| `supplier`     | `VARCHAR(255)`              |                                      |
| `location`     | `VARCHAR(120)`              |                                      |
| `tax_rate`     | `NUMERIC(5,2)`              | `NOT NULL DEFAULT 0`                 |
| `is_taxable`   | `BOOLEAN`                   | `NOT NULL DEFAULT true`              |
| `image_url`    | `TEXT`                      |                                      |
| `created_at`   | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at`   | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `created_by`   | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |

**Indexes:** `category`, `status`, `name` (trigram).

**RLS:** Users with `admin`, `operations`, or `sales` roles can CRUD.

---

### `sales_orders`

| Column            | Type                        | Constraints                          |
|-------------------|-----------------------------|--------------------------------------|
| `id`              | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `invoice_no`      | `VARCHAR(50)`               | `UNIQUE NOT NULL` — auto-generated `INV-YYYYMMDD-XXXXX` |
| `customer_id`     | `UUID`                      | → `customers(id) ON DELETE SET NULL` |
| `order_date`      | `TIMESTAMP WITH TIME ZONE`  | `NOT NULL DEFAULT now()`             |
| `due_date`        | `DATE`                      |                                      |
| `subtotal`        | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `discount_amount` | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `tax_amount`      | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `shipping_amount` | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `grand_total`     | `NUMERIC(18,2)`             | `NOT NULL` — `>= 0`                  |
| `paid_amount`     | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `due_amount`      | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `payment_status`  | `VARCHAR(20)`               | `NOT NULL DEFAULT 'UNPAID'` — check: `unpaid`, `partial`, `paid`, `refunded`, `cancelled` |
| `sales_status`    | `VARCHAR(20)`               | `NOT NULL DEFAULT 'COMPLETED'` — check: `draft`, `pending`, `completed`, `cancelled`, `refunded` |
| `notes`           | `TEXT`                      |                                      |
| `created_by`      | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |
| `created_at`      | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at`      | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** `customer_id`, `order_date DESC`, `payment_status`, `sales_status`.

**RLS:** Users with `admin`, `operations`, or `sales` roles can CRUD.

---

### `sales_order_items`

| Column            | Type                        | Constraints                          |
|-------------------|-----------------------------|--------------------------------------|
| `id`              | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `sales_order_id`  | `UUID`                      | `NOT NULL` → `sales_orders(id) ON DELETE CASCADE` |
| `product_id`      | `UUID`                      | `NOT NULL` → `products(id) ON DELETE RESTRICT` |
| `quantity`        | `NUMERIC(18,2)`             | `NOT NULL` — `> 0`                   |
| `unit_price`      | `NUMERIC(18,2)`             | `NOT NULL` — `>= 0`                  |
| `discount_amount` | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `tax_amount`      | `NUMERIC(18,2)`             | `NOT NULL DEFAULT 0`                 |
| `line_total`      | `NUMERIC(18,2)`             | `NOT NULL` — `>= 0`                  |
| `created_at`      | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** `sales_order_id`, `product_id`.

**Triggers:** Auto-decrements product stock on insert.

---

### `sales_payments`

| Column           | Type                        | Constraints                          |
|------------------|-----------------------------|--------------------------------------|
| `id`             | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `sales_order_id` | `UUID`                      | `NOT NULL` → `sales_orders(id) ON DELETE CASCADE` |
| `payment_date`   | `TIMESTAMP WITH TIME ZONE`  | `NOT NULL DEFAULT now()`             |
| `amount`         | `NUMERIC(18,2)`             | `NOT NULL` — `> 0`                   |
| `payment_method` | `VARCHAR(30)`               |                                      |
| `transaction_no` | `VARCHAR(100)`              |                                      |
| `remarks`        | `TEXT`                      |                                      |
| `received_by`    | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |
| `created_at`     | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** `sales_order_id`.

**RLS:** Inherits from `sales_orders` (same `can_manage_sales()` check).

---

### `employees`

| Column           | Type                        | Constraints                          |
|------------------|-----------------------------|--------------------------------------|
| `id`             | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `employee_code`  | `VARCHAR(20)`               | `NOT NULL UNIQUE`                    |
| `first_name`     | `VARCHAR(100)`              | `NOT NULL`                           |
| `last_name`      | `VARCHAR(100)`              |                                      |
| `email`          | `VARCHAR(150)`              |                                      |
| `phone`          | `VARCHAR(20)`               |                                      |
| `gender`         | `VARCHAR(20)`               | check: `male`, `female`, `other`, `prefer_not_to_say` |
| `dob`            | `DATE`                      |                                      |
| `joining_date`   | `DATE`                      |                                      |
| `department`     | `VARCHAR(100)`              |                                      |
| `designation`    | `VARCHAR(100)`              |                                      |
| `linked_user_id` | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |
| `employment_type`| `VARCHAR(50)`               | `NOT NULL DEFAULT 'permanent'` — check: `permanent`, `contract`, `intern`, `probation`, `part_time` |
| `basic_salary`   | `NUMERIC(12,2)`             | `NOT NULL DEFAULT 0` — `>= 0`        |
| `status`         | `VARCHAR(20)`               | `NOT NULL DEFAULT 'active'` — check: `active`, `inactive`, `on_leave`, `terminated` |
| `created_at`     | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at`     | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** `linked_user_id`, `status`, `first_name` + `last_name`.

**RLS:** Users with `admin` or `hr` roles can CRUD.

**Triggers:** Auto-creates employee record when a profile's role changes to `operations`, `hr`, or `sales`.

---

### `attendance`

| Column              | Type                        | Constraints                          |
|---------------------|-----------------------------|--------------------------------------|
| `id`                | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `employee_id`       | `UUID`                      | `NOT NULL` → `employees(id) ON DELETE CASCADE` |
| `attendance_date`   | `DATE`                      | `NOT NULL`                           |
| `check_in`          | `TIMESTAMP WITH TIME ZONE`  |                                      |
| `check_out`         | `TIMESTAMP WITH TIME ZONE`  |                                      |
| `work_hours`        | `NUMERIC(5,2)`              | `NOT NULL DEFAULT 0` — `>= 0`        |
| `late_minutes`      | `INTEGER`                   | `NOT NULL DEFAULT 0` — `>= 0`        |
| `overtime_hours`    | `NUMERIC(5,2)`              | `NOT NULL DEFAULT 0` — `>= 0`        |
| `attendance_status` | `VARCHAR(20)`               | `NOT NULL DEFAULT 'Present'` — check: `present`, `absent`, `late`, `half_day`, `holiday`, `weekend`, `leave` |
| `remarks`           | `TEXT`                      |                                      |
| `created_at`        | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at`        | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** Unique on `(employee_id, attendance_date)`, plus `attendance_date`, `attendance_status`.

**RLS:** Users with `admin` or `hr` roles can CRUD.

---

### `attendance_logs`

| Column        | Type                        | Constraints                          |
|---------------|-----------------------------|--------------------------------------|
| `id`          | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `employee_id` | `UUID`                      | `NOT NULL` → `employees(id) ON DELETE CASCADE` |
| `log_time`    | `TIMESTAMP WITH TIME ZONE`  | `NOT NULL DEFAULT now()`             |
| `log_type`    | `VARCHAR(20)`               | `NOT NULL` — check: `check_in`, `check_out`, `break_start`, `break_end` |
| `device_id`   | `UUID`                      |                                      |
| `location`    | `VARCHAR(255)`              |                                      |
| `created_at`  | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** `employee_id`, `log_time`, `log_type`.

**RLS:** Users with `admin` or `hr` roles can CRUD.

---

### `access_requests`

| Column           | Type                        | Constraints                          |
|------------------|-----------------------------|--------------------------------------|
| `id`             | `UUID`                      | PK `DEFAULT gen_random_uuid()`       |
| `user_id`        | `UUID`                      | `NOT NULL` → `profiles(id) ON DELETE CASCADE` |
| `requested_role` | `VARCHAR(20)`               | `NOT NULL` — check: `operations`, `hr`, `sales` |
| `status`         | `VARCHAR(20)`               | `NOT NULL DEFAULT 'pending'` — check: `pending`, `approved`, `rejected` |
| `reviewed_by`    | `UUID`                      | → `profiles(id) ON DELETE SET NULL`  |
| `reviewed_at`    | `TIMESTAMP WITH TIME ZONE`  |                                      |
| `notes`          | `TEXT`                      |                                      |
| `created_at`     | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |
| `updated_at`     | `TIMESTAMP WITH TIME ZONE`  | `DEFAULT now()`                      |

**Indexes:** `user_id`, `status`.

**RLS:** Users read/insert own requests; admins read/update all.
