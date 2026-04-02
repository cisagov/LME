# Outstanding Issues - To-Do Feature

## Alert Name Display Issue
- **Problem**: When promoting alerts to the To-Do list, the title shows random Elasticsearch IDs (e.g., "KjDfTp0BwpzhJ5pr0Tl8") instead of the alert name/description
- **Expected**: Should display the rule name or description like it does for vulnerabilities (e.g., "CVE-2024-35948")
- **Root Cause**: The `getTodoTitle()` function isn't finding the rule name in the stored source_data object. Need to verify what fields are actually stored and retrieve the correct one.
- **Affected Sources**: Kibana alerts, Wazuh alerts, Sysmon alerts, Defender alerts
- **Next Steps**: 
  1. Add console logging to determine exact field names in stored source_data
  2. May need to update the promoteTodo endpoint to extract and store the rule_name separately
  3. Update getTodoTitle() to use the correct field names

## Current Version: v2.3.4

## Completed Features
- ✅ Promote button functionality (working)
- ✅ Promote state indicator (green button + checkmark when promoted)
- ✅ To-Do tab with expandable machines
- ✅ Status filtering (Pending, In-Progress, Remediated, Ignored)
- ✅ Items organized by status, then sorted by severity within each status
- ✅ Active item count in header (pending + in-progress only)
- ✅ Vulnerabilities show correct titles (CVE IDs)
- ✅ Color-coded status and severity badges
