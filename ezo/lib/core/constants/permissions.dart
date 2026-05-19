class AppPermissions {
  static const String viewDashboard = 'view_dashboard';
  static const String accessPos = 'pos_access';
  static const String viewTransactions = 'view_transactions';
  static const String manageProducts = 'manage_products';
  static const String manageCustomers = 'manage_customers';
  static const String manageSuppliers = 'manage_suppliers';
  static const String manageEmployees = 'manage_employees';
  static const String viewReports = 'view_reports';
  static const String manageSettings = 'manage_settings';
  static const String manageProfile = 'manage_profile';
  static const String manageInvoiceTemplates = 'manage_invoice_templates';
  static const String changePosLayout = 'change_pos_layout';

  static const String viewInvoices = 'view_invoices';
  static const String editInvoices = 'edit_invoices';
  static const String deleteInvoices = 'delete_invoices';

  static Map<String, String> labels = {
    viewDashboard: "View Dashboard",
    accessPos: "Access POS",
    viewTransactions: "View Transactions",
    manageProducts: "Manage Products (Inventory)",
    manageCustomers: "Manage Customers",
    manageSuppliers: "Manage Suppliers",
    manageEmployees: "Manage Employees",
    viewReports: "View Reports",
    manageSettings: "Manage Settings",
    manageProfile: "Manage Company Profile",
    manageInvoiceTemplates: "Manage Invoice Templates",
    changePosLayout: "Change POS Screen Layout",
    viewInvoices: "View Invoices",
    editInvoices: "Process Returns & Exchanges",
    deleteInvoices: "Delete Invoices",
  };
}
