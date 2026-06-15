const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
const logger = require('./logger');

class Reporter {
  constructor() {
    this.tests = [];
    this.failures = [];
    this.logs = [];
  }

  addTestRecord(record) {
    this.tests.push({
      testId: record.testId || `TC_${this.tests.length + 1}`,
      module: record.module || 'Default',
      scenario: record.scenario || 'Default Scenario',
      device: record.device || 'Android',
      status: record.status || 'Passed',
      startTime: record.startTime || new Date(),
      endTime: record.endTime || new Date(),
      duration: record.duration || 0
    });
  }

  addFailureRecord(record) {
    this.failures.push({
      testName: record.testName || 'Unknown Test',
      reason: record.reason || 'Unknown Failure',
      screenshotPath: record.screenshotPath || 'N/A',
      device: record.device || 'Android',
      androidVersion: record.androidVersion || 'N/A',
      activityName: record.activityName || 'N/A'
    });
  }

  addLogRecord(record) {
    this.logs.push({
      timestamp: record.timestamp || new Date().toISOString(),
      testName: record.testName || 'Global',
      step: record.step || 'Step description',
      result: record.result || 'Info',
      remarks: record.remarks || ''
    });
  }

  async generateExcelReport(deviceName = 'Android Device', androidVersion = '13') {
    const reportsDir = path.resolve(__dirname, '../reports');
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir, { recursive: true });
    }

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'SmartMenu QA Automation Architect';
    workbook.created = new Date();

    // Sheet 1 - Summary
    const summarySheet = workbook.addWorksheet('Summary');
    summarySheet.columns = [
      { header: 'Execution Date', key: 'execDate', width: 22 },
      { header: 'Device Name', key: 'deviceName', width: 20 },
      { header: 'Android Version', key: 'androidVersion', width: 15 },
      { header: 'Total Tests', key: 'totalTests', width: 12 },
      { header: 'Passed', key: 'passed', width: 10 },
      { header: 'Failed', key: 'failed', width: 10 },
      { header: 'Skipped', key: 'skipped', width: 10 },
      { header: 'Pass Percentage', key: 'passPercentage', width: 18 },
      { header: 'Execution Duration (ms)', key: 'duration', width: 25 }
    ];

    const totalTests = this.tests.length;
    const passed = this.tests.filter(t => t.status.toLowerCase() === 'passed').length;
    const failed = this.tests.filter(t => t.status.toLowerCase() === 'failed').length;
    const skipped = this.tests.filter(t => t.status.toLowerCase() === 'skipped').length;
    const passPercentage = totalTests > 0 ? `${Math.round((passed / totalTests) * 100)}%` : '0%';
    const totalDuration = this.tests.reduce((acc, t) => acc + t.duration, 0);

    summarySheet.addRow({
      execDate: new Date().toLocaleString(),
      deviceName,
      androidVersion,
      totalTests,
      passed,
      failed,
      skipped,
      passPercentage,
      duration: totalDuration
    });

    // Style summary headers
    summarySheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' } };
    summarySheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: '1F497D' }
    };

    // Sheet 2 - Test Cases
    const testCasesSheet = workbook.addWorksheet('Test Cases');
    testCasesSheet.columns = [
      { header: 'Test ID', key: 'testId', width: 12 },
      { header: 'Module', key: 'module', width: 20 },
      { header: 'Scenario', key: 'scenario', width: 45 },
      { header: 'Device', key: 'device', width: 20 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Start Time', key: 'startTime', width: 22 },
      { header: 'End Time', key: 'endTime', width: 22 },
      { header: 'Duration (ms)', key: 'duration', width: 15 }
    ];

    this.tests.forEach(t => {
      testCasesSheet.addRow({
        testId: t.testId,
        module: t.module,
        scenario: t.scenario,
        device: t.device,
        status: t.status,
        startTime: t.startTime.toISOString(),
        endTime: t.endTime.toISOString(),
        duration: t.duration
      });
    });

    testCasesSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' } };
    testCasesSheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: '366092' }
    };

    // Sheet 3 - Failed Tests
    const failuresSheet = workbook.addWorksheet('Failed Tests');
    failuresSheet.columns = [
      { header: 'Test Name', key: 'testName', width: 35 },
      { header: 'Failure Reason', key: 'reason', width: 50 },
      { header: 'Screenshot Path', key: 'screenshotPath', width: 60 },
      { header: 'Device', key: 'device', width: 20 },
      { header: 'Android Version', key: 'androidVersion', width: 15 },
      { header: 'Activity Name', key: 'activityName', width: 35 }
    ];

    this.failures.forEach(f => {
      failuresSheet.addRow(f);
    });

    failuresSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' } };
    failuresSheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'C00000' }
    };

    // Sheet 4 - Execution Logs
    const logsSheet = workbook.addWorksheet('Execution Logs');
    logsSheet.columns = [
      { header: 'Timestamp', key: 'timestamp', width: 22 },
      { header: 'Test Name', key: 'testName', width: 35 },
      { header: 'Step', key: 'step', width: 45 },
      { header: 'Result', key: 'result', width: 12 },
      { header: 'Remarks', key: 'remarks', width: 50 }
    ];

    this.logs.forEach(l => {
      logsSheet.addRow(l);
    });

    logsSheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFF' } };
    logsSheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: '595959' }
    };

    const filePath = path.join(reportsDir, 'Mobile_E2E_Report.xlsx');
    const rootFilePath = path.resolve(__dirname, '../../Mobile_E2E_Report.xlsx');
    await workbook.xlsx.writeFile(filePath);
    try {
      await workbook.xlsx.writeFile(rootFilePath);
      logger.info(`Excel report successfully written to workspace root: ${rootFilePath}`);
    } catch (err) {
      logger.warn(`Could not write Excel report to workspace root: ${err.message}`);
    }
    logger.info(`Excel report successfully written to ${filePath}`);
    return filePath;
  }

  async generateCSVReport() {
    const reportsDir = path.resolve(__dirname, '../reports');
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir, { recursive: true });
    }

    const frameworkCsvPath = path.join(reportsDir, 'Mobile_E2E_Report.csv');
    const rootCsvPath = path.resolve(__dirname, '../../Mobile_E2E_Report.csv');
    logger.info(`Generating CSV report at: ${frameworkCsvPath}`);
    let csvContent = 'Test ID,Module,Scenario,Device,Status,Start Time,End Time,Duration (ms),Failure Reason\n';
    
    this.tests.forEach(t => {
      const failure = this.failures.find(f => f.testName.includes(t.scenario)) || {};
      const reason = failure.reason ? failure.reason.replace(/"/g, '""').replace(/\n/g, ' ') : '';
      
      const row = [
        t.testId,
        `"${t.module}"`,
        `"${t.scenario}"`,
        `"${t.device}"`,
        t.status,
        t.startTime.toISOString(),
        t.endTime.toISOString(),
        t.duration,
        `"${reason}"`
      ];
      csvContent += row.join(',') + '\n';
    });

    fs.writeFileSync(frameworkCsvPath, csvContent, 'utf8');
    fs.writeFileSync(rootCsvPath, csvContent, 'utf8');
    logger.info(`CSV report successfully written to ${frameworkCsvPath}`);
    logger.info(`CSV report successfully written to workspace root: ${rootCsvPath}`);
    return frameworkCsvPath;
  }

  async generateTestingLogsCSV(limit = 30) {
    const reportsDir = path.resolve(__dirname, '../reports');
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir, { recursive: true });
    }

    const frameworkCsvPath = path.join(reportsDir, 'Mobile_E2E_Testing_Logs_30.csv');
    const rootCsvPath = path.resolve(__dirname, '../../Mobile_E2E_Testing_Logs_30.csv');
    let csvContent = 'Log ID,Timestamp,Test Name,Step,Result,Remarks\n';

    const testOutcomeLogs = this.tests.slice(0, limit).map((test, index) => ({
      logId: `LOG_${String(index + 1).padStart(2, '0')}`,
      timestamp: test.endTime.toISOString(),
      testName: test.scenario,
      step: 'End-to-end validation',
      result: test.status,
      remarks: `${test.module} completed in ${test.duration}ms on ${test.device}`
    }));

    testOutcomeLogs.forEach(log => {
      const row = [
        log.logId,
        log.timestamp,
        `"${log.testName.replace(/"/g, '""')}"`,
        `"${log.step}"`,
        log.result,
        `"${log.remarks.replace(/"/g, '""')}"`
      ];
      csvContent += row.join(',') + '\n';
    });

    fs.writeFileSync(frameworkCsvPath, csvContent, 'utf8');
    fs.writeFileSync(rootCsvPath, csvContent, 'utf8');
    logger.info(`30-row testing logs CSV written to ${frameworkCsvPath}`);
    logger.info(`30-row testing logs CSV written to workspace root: ${rootCsvPath}`);
    return frameworkCsvPath;
  }
}

// Global instance to gather results from mocha tests
const globalReporter = new Reporter();

module.exports = {
  Reporter,
  globalReporter
};
