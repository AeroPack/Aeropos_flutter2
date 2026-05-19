# Stitch UI Prompt: Complete Reporting Page

## Project Overview
Design a production-ready **Reporting Dashboard Page** for a SaaS application (CRM + POS system). The page serves as a business intelligence hub for business owners to monitor performance, track KPIs, and make data-driven decisions.

---

## Technical Stack
- **Framework**: React
- **UI Library**: ShadCN UI
- **Styling**: Tailwind CSS
- **Charts**: Recharts (ShadCN-compatible)
- **Data Table**: TanStack Table (ShadCN-compatible)

---

## Page Structure

### Layout (DO NOT include - already defined globally)
- Header: Already exists
- Sidebar: Already exists
- Content Area: Full-width dashboard container with padding

### Dashboard Sections (Top to Bottom)

#### 1. Header Section
- Page title: "Reports" or "Analytics Dashboard"
- Subtitle: Dynamic date range display (e.g., "January 1 - March 25, 2026")
- Action buttons: Export dropdown (CSV, PDF, Excel), Refresh button, Real-time toggle switch

#### 2. Filter Bar
- **Date Range Picker**: Custom date range selector with presets (Today, Yesterday, Last 7 Days, Last 30 Days, This Month, Last Month)
- **Multi-select Dropdowns**:
  - Location/Branch filter
  - Product Category filter
  - Agent/Staff filter
- **Clear All Filters** button

#### 3. KPI Summary Cards Row (4 cards)
Display key metrics with comparison to previous period:

| Metric Card | Value Display | Comparison | Chart Type |
|-------------|---------------|------------|------------|
| Total Revenue | Currency format (e.g., $124,500) | % change + absolute difference | Mini sparkline (line) |
| Total Orders | Number format (e.g., 1,234) | % change + absolute difference | Mini sparkline (line) |
| Average Order Value (AOV) | Currency format (e.g., $85.20) | % change + absolute difference | Mini sparkline (line) |
| Total Active Customers | Number format (e.g., 5,678) | % change + absolute difference | Mini sparkline (line) |

**Card Behavior**:
- Click to expand into detailed view
- Hover shows tooltip with exact values
- Green indicator for positive change, red for negative

#### 4. Revenue Analytics Section (Two-column on desktop)

**Left Column: Revenue Over Time**
- **Chart Type**: Area/Line chart
- **X-axis**: Time (days/weeks/months based on date range)
- **Y-axis**: Revenue in currency
- **Data Points**: Daily revenue with trend line
- **Interactions**: Hover tooltip showing exact value, date, click to drill down

**Right Column: Orders Over Time**
- **Chart Type**: Line chart with bar overlay
- **X-axis**: Time (days/weeks/months)
- **Y-axis**: Order count
- **Data Points**: Order volume with average trend line

#### 5. Customer Analytics Section (Full-width)

**Metrics Cards Row (4 cards)**:
| Metric | Display | Comparison |
|--------|---------|------------|
| New Customers | Count | vs previous period |
| Returning Customers | Count | vs previous period |
| Customer Retention Rate | Percentage | vs previous period |
| Top Customer Revenue | Currency | vs previous top customer |

**Customer Distribution Chart**:
- **Chart Type**: Donut/Pie chart
- **Segments**: New Customers vs Returning Customers
- **Center**: Total customer count
- **Legend**: Clickable to filter

#### 6. POS Detailed Analytics Section (Full-width)

**Top Products Performance**:
- **Chart Type**: Horizontal bar chart
- **Data**: Top 10 products by revenue
- **Metrics**: Product name, quantity sold, revenue, % of total
- **Interactions**: Click product to see detailed sales breakdown

**Payment Methods Distribution**:
- **Chart Type**: Donut/Pie chart
- **Segments**: Cash, Credit Card, Debit Card, UPI, Wallet, Other
- **Legend**: Payment method with percentage and amount

**Sales by Category**:
- **Chart Type**: Stacked bar chart
- **X-axis**: Time periods
- **Y-axis**: Revenue by category
- **Categories**: Product categories from POS

#### 7. Agent/Staff Performance Section (Full-width, collapsible)

**Agent Leaderboard Table**:
- **Columns**: 
  - Agent Name (with avatar)
  - Total Sales (currency)
  - Orders Completed (count)
  - Average Order Value (currency)
  - Performance vs Previous Period (percentage with indicator)
- **Sorting**: Click column headers to sort
- **Pagination**: 10 rows per page
- **Actions**: Click row to view agent's detailed report

#### 8. Geographic/Location Breakdown (If multiple locations)

**Revenue by Location**:
- **Chart Type**: Bar chart
- **Data**: Each location/branch with revenue
- **Comparison**: vs previous period

---

## UX Behavior

### Loading States
- **Skeleton loaders**: Display ShadCN skeleton components for all cards and charts while loading
- **Duration**: Show shimmer animation for 200ms minimum
- **Partial loading**: Charts load sequentially, cards can load independently

### Empty States
- **No data for date range**: Display illustration with "No transactions found for selected period" + "Try adjusting your filters"
- **No customers yet**: Display "No customer data available" with CTA to add first customer
- **Empty chart**: Show "No data to display" placeholder within chart area

### Drill-down Interactions
- **KPI Card Click**: Expands to show daily/weekly breakdown in modal or inline expansion
- **Chart Data Point Click**: Opens side panel with detailed breakdown
- **Table Row Click**: Navigates to detailed view or opens modal with full customer/order history

### Hover States
- **Cards**: Slight elevation (shadow increase), cursor pointer
- **Chart Points**: Tooltip with formatted value, date, and percentage of total
- **Table Rows**: Background highlight (#f4f4f5 or dark mode equivalent)

### Real-time Toggle Behavior
- **ON**: Auto-refresh data every 30 seconds, show "Live" indicator with pulse animation
- **OFF**: Manual refresh only, show "Last updated: [timestamp]"
- **Transition**: Fade animation when switching states

---

## Data Visualization Logic

### Why Each Chart Matters

| Chart | Purpose | Business Insight |
|-------|---------|------------------|
| Revenue Over Time | Trend analysis | Identify growth patterns, seasonal trends |
| Orders Over Time | Volume analysis | Understand busy periods, demand fluctuation |
| Customer Distribution | Segmentation | New vs returning customer health |
| Top Products | Inventory/SKU analysis | Best performers, pricing optimization |
| Payment Methods | Revenue streams | Customer payment preferences |
| Sales by Category | Product mix | Which categories drive revenue |
| Agent Performance | Team productivity | Top performers, training needs |
| Location Breakdown | Regional performance | Best/worst performing locations |

### Comparison Logic
- **Percentage Change**: (Current Period - Previous Period) / Previous Period × 100
- **Absolute Difference**: Current Period - Previous Period
- **Color Coding**: Green (#22c55e) for positive, Red (#ef4444) for negative
- **Arrow Indicators**: ↑ for increase, ↓ for decrease

---

## Advanced Features

### Export Functionality
- **CSV Export**: All visible data with current filters applied
- **PDF Export**: Branded PDF with dashboard snapshot, date range, filters applied
- **Excel Export**: Formatted spreadsheet with separate sheets for each section
- **Export Button**: Dropdown menu in header, shows progress indicator

### Comparison Mode
- **Toggle**: Show/hide previous period data on all charts
- **Visual**: Previous period shown as dotted/dashed line on line charts
- **Table**: Add "Previous Period" column to all data tables

### Real-time Data (Hybrid)
- **Toggle Switch**: In header, clearly labeled "Live"
- **Auto-refresh**: 30-second interval when enabled
- **Manual Refresh**: Refresh icon button always available
- **Status Indicator**: "Live" with green dot, "Last updated [time]" when off

---

## Filters Specification

### Date Range Filter
- **Type**: Date range picker with presets
- **Presets**: Today, Yesterday, Last 7 Days, Last 30 Days, This Month, Last Month, Custom
- **Custom**: Calendar picker for start and end date
- **Default**: Last 30 Days

### Multi-select Filters
- **Location/Branch**: Checkbox list, select all option, search
- **Product Category**: Checkbox list from POS categories
- **Agent/Staff**: Checkbox list with search, shows only active agents
- **Behavior**: AND logic between different filter types

### Filter Persistence
- Store filter selections in URL params for shareability
- Remember last used filters in localStorage

---

## Responsive Behavior

### Desktop (> 1024px)
- Full 4-column KPI cards
- Two-column chart sections
- Full table with all columns

### Tablet (768px - 1024px)
- 2-column KPI cards
- Single column charts
- Table with horizontal scroll

### Mobile (< 768px)
- Single column KPI cards (2x2 grid)
- Stacked charts
- Condensed table (key columns only)
- Collapsible sections

---

## Accessibility Requirements
- All charts have aria-labels describing the data
- Color is not the only indicator (use icons, patterns for comparison)
- Keyboard navigation for all interactive elements
- Focus visible states on all interactive elements
- Screen reader announcements for filter changes

---

## Color Palette (System Default Theme Support)
- **Primary**: Use application's theme colors
- **Success/Positive**: #22c55e (green-500)
- **Error/Negative**: #ef4444 (red-500)
- **Neutral**: #71717a (zinc-500)
- **Chart Colors**: Use a consistent palette across all charts
  - Primary: #3b82f6 (blue-500)
  - Secondary: #8b5cf6 (violet-500)
  - Tertiary: #f59e0b (amber-500)
  - Quaternary: #ec4899 (pink-500)

---

## Implementation Notes for Stitch UI

### Use ShadCN Components
- Card (for KPI cards and sections)
- Table (for data tables)
- Select (for filters)
- Button (for actions)
- Dropdown Menu (for export)
- Switch (for real-time toggle)
- Skeleton (for loading states)
- Badge (for status indicators)
- Tooltip (for hover information)

### Chart Implementation
- Use Recharts library (ShadCN compatible)
- Consistent tooltip styling across all charts
- ResponsiveContainer for fluid width
- Custom legends where appropriate

### Code Structure
```
src/
  components/
    reporting/
      ReportingDashboard.tsx
      KPICard.tsx
      RevenueChart.tsx
      OrdersChart.tsx
      CustomerDistribution.tsx
      TopProductsChart.tsx
      PaymentMethodsChart.tsx
      AgentPerformanceTable.tsx
      FilterBar.tsx
      DateRangePicker.tsx
      ExportMenu.tsx
```

---

## Success Criteria
1. All KPIs display with correct formatting and comparison
2. All charts render with proper data and interactions
3. Filters correctly update all dashboard components
4. Export generates accurate files in all formats
5. Real-time toggle functions correctly
6. Drill-down interactions provide detailed data
7. Responsive layout works across all breakpoints
8. Loading and empty states display appropriately
9. Theme adapts to light/dark mode (system default)
10. Page loads within 2 seconds with cached data
