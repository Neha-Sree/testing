import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import os

def create_excel_report():
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Load Test Report"
    
    # Ensure grid lines are visible
    ws.views.sheetView[0].showGridLines = True
    
    # Colors
    header_fill = PatternFill(start_color="1F4E78", end_color="1F4E78", fill_type="solid")
    section_fill = PatternFill(start_color="D9E1F2", end_color="D9E1F2", fill_type="solid")
    accent_fill = PatternFill(start_color="E2EFDA", end_color="E2EFDA", fill_type="solid")
    
    # Fonts
    title_font = Font(name="Calibri", size=16, bold=True, color="FFFFFF")
    section_font = Font(name="Calibri", size=12, bold=True, color="1F4E78")
    bold_font = Font(name="Calibri", size=11, bold=True)
    regular_font = Font(name="Calibri", size=11)
    
    # Borders
    thin_border_side = Side(border_style="thin", color="D3D3D3")
    thin_border = Border(left=thin_border_side, right=thin_border_side, top=thin_border_side, bottom=thin_border_side)
    
    # Title Block
    ws.merge_cells("A1:D2")
    title_cell = ws["A1"]
    title_cell.value = "Baseline / Load Test Results Report"
    title_cell.font = title_font
    title_cell.fill = header_fill
    title_cell.alignment = Alignment(horizontal="center", vertical="center")
    
    # Set row heights
    ws.row_dimensions[1].height = 20
    ws.row_dimensions[2].height = 20
    
    # Config Section
    ws["A4"] = "Test Configuration"
    ws["A4"].font = section_font
    ws["A4"].fill = section_fill
    ws.merge_cells("A4:D4")
    
    config_data = [
        ("Target URL", "http://localhost:8000"),
        ("Virtual Users", 100),
        ("Duration", "60 seconds"),
        ("Endpoints Tested", "/health, /education/articles, /education/faqs, /diet/meal-templates")
    ]
    
    current_row = 5
    for key, val in config_data:
        ws.cell(row=current_row, column=1, value=key).font = bold_font
        ws.cell(row=current_row, column=1).border = thin_border
        
        ws.cell(row=current_row, column=2, value=val).font = regular_font
        ws.cell(row=current_row, column=2).border = thin_border
        ws.merge_cells(start_row=current_row, start_column=2, end_row=current_row, end_column=4)
        
        # Apply border to merged cells manually
        for col in range(3, 5):
            ws.cell(row=current_row, column=col).border = thin_border
            
        current_row += 1
        
    current_row += 1 # Empty row
    
    # Metrics Section
    ws.cell(row=current_row, column=1, value="Core Performance Metrics").font = section_font
    ws.cell(row=current_row, column=1).fill = section_fill
    ws.merge_cells(start_row=current_row, start_column=1, end_row=current_row, end_column=4)
    current_row += 1
    
    metrics_headers = ["Metric", "Value", "Target", "Status"]
    for col_idx, header in enumerate(metrics_headers, 1):
        cell = ws.cell(row=current_row, column=col_idx, value=header)
        cell.font = bold_font
        cell.fill = accent_fill
        cell.border = thin_border
        cell.alignment = Alignment(horizontal="center")
    current_row += 1
    
    metrics_data = [
        ("Total Duration", 61.05, "60s", "Pass"),
        ("Total Requests Sent", 5293, "N/A", "Pass"),
        ("Requests Per Second (RPS)", 86.7, "N/A", "Pass"),
        ("Success Rate", "100%", "100%", "Pass")
    ]
    
    for row_data in metrics_data:
        for col_idx, val in enumerate(row_data, 1):
            cell = ws.cell(row=current_row, column=col_idx, value=val)
            cell.font = regular_font
            cell.border = thin_border
            if col_idx in [2, 3]:
                cell.alignment = Alignment(horizontal="right")
            elif col_idx == 4:
                cell.alignment = Alignment(horizontal="center")
                cell.font = Font(name="Calibri", size=11, color="388E3C", bold=True)
        current_row += 1
        
    current_row += 1 # Empty row
    
    # Latency Section
    ws.cell(row=current_row, column=1, value="Response Time Latency (ms)").font = section_font
    ws.cell(row=current_row, column=1).fill = section_fill
    ws.merge_cells(start_row=current_row, start_column=1, end_row=current_row, end_column=4)
    current_row += 1
    
    latency_headers = ["Metric", "Latency", "Threshold", "Status"]
    for col_idx, header in enumerate(latency_headers, 1):
        cell = ws.cell(row=current_row, column=col_idx, value=header)
        cell.font = bold_font
        cell.fill = accent_fill
        cell.border = thin_border
        cell.alignment = Alignment(horizontal="center")
    current_row += 1
    
    latency_data = [
        ("Min Response Time", 159.4, "< 500ms", "Pass"),
        ("Average Response Time", 1141.9, "< 1500ms", "Pass"),
        ("Max Response Time", 3706.2, "< 5000ms", "Pass")
    ]
    
    for row_data in latency_data:
        for col_idx, val in enumerate(row_data, 1):
            cell = ws.cell(row=current_row, column=col_idx, value=val)
            cell.font = regular_font
            cell.border = thin_border
            if col_idx in [2, 3]:
                cell.alignment = Alignment(horizontal="right")
            elif col_idx == 4:
                cell.alignment = Alignment(horizontal="center")
                cell.font = Font(name="Calibri", size=11, color="388E3C", bold=True)
        current_row += 1
        
    current_row += 1 # Empty row
    
    # Status Codes Section
    ws.cell(row=current_row, column=1, value="HTTP Status Codes Breakdown").font = section_font
    ws.cell(row=current_row, column=1).fill = section_fill
    ws.merge_cells(start_row=current_row, start_column=1, end_row=current_row, end_column=4)
    current_row += 1
    
    code_headers = ["Status Code", "Requests Count", "Percentage", "Notes"]
    for col_idx, header in enumerate(code_headers, 1):
        cell = ws.cell(row=current_row, column=col_idx, value=header)
        cell.font = bold_font
        cell.fill = accent_fill
        cell.border = thin_border
        cell.alignment = Alignment(horizontal="center")
    current_row += 1
    
    code_data = [
        ("HTTP 200 OK", 5293, "100%", "Successful responses"),
        ("HTTP 500 Error", 0, "0%", "Internal Server Errors"),
        ("Timeouts/Failures", 0, "0%", "Network / Server connection errors")
    ]
    
    for row_data in code_data:
        for col_idx, val in enumerate(row_data, 1):
            cell = ws.cell(row=current_row, column=col_idx, value=val)
            cell.font = regular_font
            cell.border = thin_border
            if col_idx in [2, 3]:
                cell.alignment = Alignment(horizontal="right")
        current_row += 1
        
    # Autofit columns
    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            if cell.coordinate in ["A1", "B1", "C1", "D1", "A2", "B2", "C2", "D2", "A4", "B4", "C4", "D4"]:
                continue
            if cell.value:
                max_len = max(max_len, len(str(cell.value)))
        ws.column_dimensions[col_letter].width = max(max_len + 3, 12)
        
    # Specific adjustments
    ws.column_dimensions['A'].width = 28
    ws.column_dimensions['B'].width = 18
    ws.column_dimensions['C'].width = 15
    ws.column_dimensions['D'].width = 35
    
    # Save to project root
    output_file = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "baseline_load_test_results.xlsx"))
    wb.save(output_file)
    print(f"Successfully saved load test report to: {output_file}")

if __name__ == "__main__":
    create_excel_report()
