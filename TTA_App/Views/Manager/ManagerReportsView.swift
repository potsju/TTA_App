import SwiftUI
import Charts

struct ManagerReportsView: View {
    @State private var selectedReport = ReportType.overview
    
    enum ReportType: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case coaches = "Coach Performance"
        case revenue = "Revenue Analysis"
        case students = "Student Activity"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Report selector
            Picker("Report Type", selection: $selectedReport) {
                ForEach(ReportType.allCases) { reportType in
                    Text(reportType.rawValue).tag(reportType)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Report content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedReport {
                    case .overview:
                        OverviewReport()
                    case .coaches:
                        CoachPerformanceReport()
                    case .revenue:
                        RevenueAnalysisReport()
                    case .students:
                        StudentActivityReport()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Financial Reports")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OverviewReport: View {
    var body: some View {
        VStack(spacing: 16) {
            // Summary section
            ReportCard(title: "Business Summary") {
                VStack(spacing: 10) {
                    StatRow(label: "Total Revenue (YTD)", value: "84,500 credits")
                    StatRow(label: "Total Expenses (YTD)", value: "42,300 credits")
                    StatRow(label: "Net Profit (YTD)", value: "42,200 credits")
                    StatRow(label: "Active Students", value: "243")
                    StatRow(label: "Active Coaches", value: "18")
                    StatRow(label: "Classes Completed (YTD)", value: "1,245")
                }
            }
            
            // Growth section
            ReportCard(title: "Growth Analysis") {
                VStack(spacing: 10) {
                    StatRow(label: "Revenue Growth (YoY)", value: "+24%", valueColor: .green)
                    StatRow(label: "New Students (This Month)", value: "32")
                    StatRow(label: "New Coaches (This Month)", value: "3")
                    StatRow(label: "Student Retention Rate", value: "87%")
                    StatRow(label: "Average Class Value", value: "75 credits")
                }
            }
            
            // Chart
            ReportCard(title: "Monthly Performance") {
                Chart {
                    LineMark(
                        x: .value("Month", "Jan"),
                        y: .value("Value", 5400)
                    )
                    LineMark(
                        x: .value("Month", "Feb"),
                        y: .value("Value", 6200)
                    )
                    LineMark(
                        x: .value("Month", "Mar"),
                        y: .value("Value", 7100)
                    )
                    LineMark(
                        x: .value("Month", "Apr"),
                        y: .value("Value", 6800)
                    )
                    LineMark(
                        x: .value("Month", "May"),
                        y: .value("Value", 7500)
                    )
                    LineMark(
                        x: .value("Month", "Jun"),
                        y: .value("Value", 8200)
                    )
                }
                .frame(height: 200)
            }
            
            // Quick actions
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Export PDF",
                    systemImage: "arrow.down.doc",
                    action: { /* PDF export */ }
                )
                
                QuickActionButton(
                    title: "Share Report",
                    systemImage: "square.and.arrow.up",
                    action: { /* Share functionality */ }
                )
            }
        }
    }
}

struct CoachPerformanceReport: View {
    var body: some View {
        VStack(spacing: 16) {
            // Top coaches
            ReportCard(title: "Top Performing Coaches") {
                VStack(spacing: 10) {
                    CoachPerformanceRow(name: "Sarah Johnson", earnings: 12400, students: 24)
                    CoachPerformanceRow(name: "Michael Chen", earnings: 10800, students: 18)
                    CoachPerformanceRow(name: "David Williams", earnings: 9500, students: 15)
                    CoachPerformanceRow(name: "Emily Rodriguez", earnings: 8700, students: 14)
                    CoachPerformanceRow(name: "James Smith", earnings: 7900, students: 12)
                }
            }
            
            // Chart
            ReportCard(title: "Coach Earnings Distribution") {
                Chart {
                    BarMark(
                        x: .value("Coach", "Sarah J."),
                        y: .value("Earnings", 12400)
                    )
                    .foregroundStyle(Color.blue)
                    
                    BarMark(
                        x: .value("Coach", "Michael C."),
                        y: .value("Earnings", 10800)
                    )
                    .foregroundStyle(Color.blue)
                    
                    BarMark(
                        x: .value("Coach", "David W."),
                        y: .value("Earnings", 9500)
                    )
                    .foregroundStyle(Color.blue)
                    
                    BarMark(
                        x: .value("Coach", "Emily R."),
                        y: .value("Earnings", 8700)
                    )
                    .foregroundStyle(Color.blue)
                    
                    BarMark(
                        x: .value("Coach", "James S."),
                        y: .value("Earnings", 7900)
                    )
                    .foregroundStyle(Color.blue)
                }
                .frame(height: 200)
            }
            
            // Coach statistics
            ReportCard(title: "Coach Statistics") {
                VStack(spacing: 10) {
                    StatRow(label: "Average Earnings per Coach", value: "4,700 credits")
                    StatRow(label: "Coach Retention Rate", value: "92%")
                    StatRow(label: "Highest Earning Coach", value: "12,400 credits")
                    StatRow(label: "Average Students per Coach", value: "13.5")
                    StatRow(label: "New Coaches (This Quarter)", value: "4")
                }
            }
        }
    }
}

struct RevenueAnalysisReport: View {
    var body: some View {
        VStack(spacing: 16) {
            // Revenue breakdown
            ReportCard(title: "Revenue Breakdown") {
                VStack(spacing: 10) {
                    StatRow(label: "Piano Classes", value: "32,400 credits (38%)")
                    StatRow(label: "Guitar Classes", value: "24,600 credits (29%)")
                    StatRow(label: "Violin Classes", value: "14,800 credits (18%)")
                    StatRow(label: "Voice Lessons", value: "8,500 credits (10%)")
                    StatRow(label: "Other Classes", value: "4,200 credits (5%)")
                }
            }
            
            // Chart
            ReportCard(title: "Monthly Revenue Trend") {
                Chart {
                    LineMark(
                        x: .value("Month", "Jan"),
                        y: .value("Revenue", 13200)
                    )
                    .foregroundStyle(Color.green)
                    
                    LineMark(
                        x: .value("Month", "Feb"),
                        y: .value("Revenue", 14500)
                    )
                    .foregroundStyle(Color.green)
                    
                    LineMark(
                        x: .value("Month", "Mar"),
                        y: .value("Revenue", 15800)
                    )
                    .foregroundStyle(Color.green)
                    
                    LineMark(
                        x: .value("Month", "Apr"),
                        y: .value("Revenue", 14200)
                    )
                    .foregroundStyle(Color.green)
                    
                    LineMark(
                        x: .value("Month", "May"),
                        y: .value("Revenue", 15900)
                    )
                    .foregroundStyle(Color.green)
                    
                    LineMark(
                        x: .value("Month", "Jun"),
                        y: .value("Revenue", 17800)
                    )
                    .foregroundStyle(Color.green)
                }
                .frame(height: 200)
            }
            
            // Revenue metrics
            ReportCard(title: "Revenue Metrics") {
                VStack(spacing: 10) {
                    StatRow(label: "Average Revenue per Student", value: "348 credits")
                    StatRow(label: "Revenue per Class", value: "68 credits")
                    StatRow(label: "Year-to-Date Growth", value: "+24%", valueColor: .green)
                    StatRow(label: "Projected Annual Revenue", value: "169,000 credits")
                    StatRow(label: "Student Lifetime Value", value: "1,240 credits")
                }
            }
        }
    }
}

struct StudentActivityReport: View {
    var body: some View {
        VStack(spacing: 16) {
            // Student statistics
            ReportCard(title: "Student Statistics") {
                VStack(spacing: 10) {
                    StatRow(label: "Total Active Students", value: "243")
                    StatRow(label: "New Students (This Month)", value: "32")
                    StatRow(label: "Student Retention Rate", value: "87%")
                    StatRow(label: "Average Classes per Student", value: "5.1")
                    StatRow(label: "Student Satisfaction", value: "4.8/5.0")
                }
            }
            
            // Chart
            ReportCard(title: "Student Growth") {
                Chart {
                    LineMark(
                        x: .value("Month", "Jan"),
                        y: .value("Students", 180)
                    )
                    .foregroundStyle(Color.blue)
                    
                    LineMark(
                        x: .value("Month", "Feb"),
                        y: .value("Students", 196)
                    )
                    .foregroundStyle(Color.blue)
                    
                    LineMark(
                        x: .value("Month", "Mar"),
                        y: .value("Students", 208)
                    )
                    .foregroundStyle(Color.blue)
                    
                    LineMark(
                        x: .value("Month", "Apr"),
                        y: .value("Students", 220)
                    )
                    .foregroundStyle(Color.blue)
                    
                    LineMark(
                        x: .value("Month", "May"),
                        y: .value("Students", 235)
                    )
                    .foregroundStyle(Color.blue)
                    
                    LineMark(
                        x: .value("Month", "Jun"),
                        y: .value("Students", 243)
                    )
                    .foregroundStyle(Color.blue)
                }
                .frame(height: 200)
            }
            
            // Student engagement
            ReportCard(title: "Student Engagement") {
                VStack(spacing: 10) {
                    StatRow(label: "Most Popular Class Type", value: "Piano (38%)")
                    StatRow(label: "Average Session Duration", value: "45 minutes")
                    StatRow(label: "Booking Conversion Rate", value: "74%")
                    StatRow(label: "Repeat Booking Rate", value: "82%")
                    StatRow(label: "Average Student Age", value: "14.2 years")
                }
            }
        }
    }
}

struct ReportCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
        .font(.subheadline)
    }
}

struct CoachPerformanceRow: View {
    let name: String
    let earnings: Int
    let students: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .fontWeight(.semibold)
                
                Text("\(students) students")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(earnings) credits")
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

struct ManagerReportsView_Previews: PreviewProvider {
    static var previews: some View {
        ManagerReportsView()
    }
} 