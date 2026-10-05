# Permissions Matrix: GearStock

This system uses a simple role-based access control (RBAC) model. Currently supported roles:
- **Owner / Admin**: Full control over the shop's data.
- **Staff**: Limited access for daily operations (scanning, stock logs).

## Access Matrix

| Resource | Action | Owner / Admin | Staff |
| :--- | :--- | :---: | :---: |
| **Products** | View | ✅ | ✅ |
| | Add New | ✅ | ❌ |
| | Edit Details | ✅ | ❌ |
| | Delete | ✅ | ❌ |
| **Stock** | Log Stock In | ✅ | ✅ |
| | Log Stock Out | ✅ | ✅ |
| | Edit/Delete Logs | ✅ | ❌ |
| **Suppliers**| View | ✅ | ✅ |
| | Add/Edit/Delete | ✅ | ❌ |
| **Reports** | View Sales/Metrics | ✅ | ❌ |
| | Export CSV | ✅ | ❌ |
| **System** | App Settings | ✅ | ❌ |
| | Manage Users | ✅ | ❌ |

## Security Rules (Supabase RLS)
- All tables must have Row Level Security (RLS) enabled.
- All reads and writes must be scoped to the shop's `tenant_id` if multi-tenancy is active, or user role if single-tenant.
- Staff accounts are blocked from mutating products or accessing reports at the database level via Supabase policies.
