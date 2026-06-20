const http = require('http');
const https = require('https');
const urlModule = require('url');
const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');

// Configuration
const targetUrl = process.env.TARGET_URL || 'http://localhost:8000/';
const concurrency = parseInt(process.env.CONCURRENCY || '100', 10);
const durationMs = parseInt(process.env.DURATION_MS || '60000', 10); // Default 1 minute
const warmupDurationMs = parseInt(process.env.WARMUP_DURATION_MS || '2000', 10); // 2s warmup

// Statistics tracking
let totalRequests = 0;
let successRequests = 0;
let failedRequests = 0;
const latencies = [];
const logs = [];

// Helper to log console output and store in logs list
function logEvent(step, result, remarks) {
  const timestamp = new Date().toISOString();
  logs.push({
    timestamp,
    testName: 'Load Test Runner',
    step,
    result,
    remarks
  });
  console.log(`[${timestamp}] [${result}] ${step}: ${remarks}`);
}

// Setup http agents to handle high concurrency with keepAlive
const parsedUrl = urlModule.parse(targetUrl);
const client = parsedUrl.protocol === 'https:' ? https : http;
const agent = new client.Agent({
  keepAlive: true,
  maxSockets: concurrency,
  keepAliveMsecs: 10000
});

// Single request promise
function makeRequest() {
  return new Promise((resolve) => {
    const startTime = Date.now();
    const options = {
      protocol: parsedUrl.protocol,
      hostname: parsedUrl.hostname,
      port: parsedUrl.port,
      path: parsedUrl.path,
      method: 'GET',
      agent: agent,
      headers: {
        'User-Agent': 'SmartMenu-Load-Tester/1.0.0',
        'Accept': 'application/json'
      },
      timeout: 5000 // 5 seconds timeout
    };

    const req = client.request(options, (res) => {
      // Consume response data to free up the socket connection
      res.on('data', () => {});
      res.on('end', () => {
        const latency = Date.now() - startTime;
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ success: true, latency });
        } else {
          resolve({ success: false, latency, error: `HTTP Status ${res.statusCode}` });
        }
      });
    });

    req.on('error', (err) => {
      const latency = Date.now() - startTime;
      resolve({ success: false, latency, error: err.message });
    });

    req.on('timeout', () => {
      req.destroy();
      const latency = Date.now() - startTime;
      resolve({ success: false, latency, error: 'Timeout' });
    });

    req.end();
  });
}

// Worker loop
async function worker(workerId, stopTime) {
  while (Date.now() < stopTime) {
    const result = await makeRequest();
    totalRequests++;
    if (result.success) {
      successRequests++;
      latencies.push(result.latency);
    } else {
      failedRequests++;
      if (failedRequests <= 5) {
        logEvent('Execution', 'Warning', `Request failed (Worker ${workerId}): ${result.error}`);
      }
      // Wait 100ms on failure to avoid flooding the socket pool
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }
}

async function run() {
  const testStartTimeStr = new Date().toISOString();
  logEvent('Setup', 'Info', `Target Endpoint: ${targetUrl}`);
  logEvent('Setup', 'Info', `Concurrency: ${concurrency} VUs`);
  logEvent('Setup', 'Info', `Warmup Duration: ${warmupDurationMs / 1000}s`);
  logEvent('Setup', 'Info', `Test Duration: ${durationMs / 1000}s`);

  // 1. Warmup Phase
  if (warmupDurationMs > 0) {
    logEvent('Warmup', 'Info', 'Initiating warmup loop to preheat connection pool...');
    const warmupStopTime = Date.now() + warmupDurationMs;
    const warmupWorkers = [];
    for (let i = 0; i < Math.min(20, concurrency); i++) {
      warmupWorkers.push(worker(i, warmupStopTime));
      // Stagger warmup worker spawn
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    await Promise.all(warmupWorkers);
    logEvent('Warmup', 'Info', 'Warmup complete. Resetting statistics counters.');
    
    // Reset stats
    totalRequests = 0;
    successRequests = 0;
    failedRequests = 0;
    latencies.length = 0;
  }

  // 2. Load Testing Phase
  const startTime = Date.now();
  const stopTime = startTime + durationMs;
  logEvent('Execution', 'Info', `Load test loop running for ${durationMs / 1000} seconds...`);

  // Progress logger interval (every 10 seconds)
  const progressInterval = setInterval(() => {
    const elapsedSec = (Date.now() - startTime) / 1000;
    const currentRps = (totalRequests / elapsedSec).toFixed(1);
    const avgLat = latencies.length > 0 ? (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(1) : 0;
    logEvent('Progress', 'Info', `${elapsedSec.toFixed(0)}s elapsed: ${totalRequests} requests, ${successRequests} succeeded, ${failedRequests} failed. RPS: ${currentRps}. Avg latency: ${avgLat}ms`);
  }, 10000);

  // Spawn all worker loops with slight staggered delay
  const workers = [];
  for (let i = 0; i < concurrency; i++) {
    workers.push(worker(i, stopTime));
    // Stagger starting each worker by 5ms to avoid slamming the port
    await new Promise(resolve => setTimeout(resolve, 5));
  }
  await Promise.all(workers);

  clearInterval(progressInterval);
  const testEndTimeStr = new Date().toISOString();
  const actualDurationMs = Date.now() - startTime;
  const durationSeconds = actualDurationMs / 1000;

  // 3. Post-execution statistics compile
  logEvent('Teardown', 'Info', 'All worker loops completed execution.');
  const rps = totalRequests / durationSeconds;

  let minLatency = 0;
  let maxLatency = 0;
  let avgLatency = 0;

  if (latencies.length > 0) {
    latencies.sort((a, b) => a - b);
    minLatency = latencies[0];
    maxLatency = latencies[latencies.length - 1];
    const sum = latencies.reduce((a, b) => a + b, 0);
    avgLatency = sum / latencies.length;
  }

  const successRate = totalRequests > 0 ? (successRequests / totalRequests) * 100 : 0;

  logEvent('Summary', 'Info', `--- Load Test Summary ---`);
  logEvent('Summary', 'Info', `Total Requests: ${totalRequests}`);
  logEvent('Summary', 'Info', `Success Count:  ${successRequests}`);
  logEvent('Summary', 'Info', `Failure Count:  ${failedRequests}`);
  logEvent('Summary', 'Info', `Success Rate:   ${successRate.toFixed(2)}%`);
  logEvent('Summary', 'Info', `Requests / Sec: ${rps.toFixed(2)} RPS`);
  logEvent('Summary', 'Info', `Min Latency:    ${minLatency} ms`);
  logEvent('Summary', 'Info', `Max Latency:    ${maxLatency} ms`);
  logEvent('Summary', 'Info', `Avg Latency:    ${avgLatency.toFixed(2)} ms`);
  logEvent('Summary', 'Info', `-------------------------`);

  // Define metric-based test scenarios
  const testScenarios = [
    {
      testId: 'TC_01',
      module: 'Performance Load Testing',
      scenario: 'RPS Baseline: Should handle high throughput (RPS >= 50)',
      device: 'Node.js Load Runner (100 VUs)',
      status: rps >= 50 ? 'Passed' : 'Failed',
      duration: Math.round(durationSeconds * 1000),
      reason: rps >= 50 ? '' : `Throughput was ${rps.toFixed(1)} RPS, target was >= 50 RPS`
    },
    {
      testId: 'TC_02',
      module: 'Performance Load Testing',
      scenario: 'Average Latency: Should respond under 500ms on average',
      device: 'Node.js Load Runner (100 VUs)',
      status: avgLatency <= 500 ? 'Passed' : 'Failed',
      duration: Math.round(avgLatency),
      reason: avgLatency <= 500 ? '' : `Average latency was ${avgLatency.toFixed(1)}ms, target was <= 500ms`
    },
    {
      testId: 'TC_03',
      module: 'Performance Load Testing',
      scenario: 'Peak Latency Check: Maximum response time under 2000ms',
      device: 'Node.js Load Runner (100 VUs)',
      status: maxLatency <= 2000 ? 'Passed' : 'Failed',
      duration: maxLatency,
      reason: maxLatency <= 2000 ? '' : `Maximum latency reached ${maxLatency}ms, target was <= 2000ms`
    },
    {
      testId: 'TC_04',
      module: 'Performance Load Testing',
      scenario: 'Request Success Rate: Should exceed 95%',
      device: 'Node.js Load Runner (100 VUs)',
      status: successRate >= 95 ? 'Passed' : 'Failed',
      duration: 0,
      reason: successRate >= 95 ? '' : `Success rate was ${successRate.toFixed(2)}%, target was >= 95%`
    },
    {
      testId: 'TC_05',
      module: 'Performance Load Testing',
      scenario: 'Concurrency Load Stability: No network errors or client failures',
      device: 'Node.js Load Runner (100 VUs)',
      status: failedRequests === 0 ? 'Passed' : 'Failed',
      duration: 0,
      reason: failedRequests === 0 ? '' : `${failedRequests} requests failed due to timeouts/network errors`
    }
  ];

  // 4. Generate Reports
  await generateExcelReport(rps, minLatency, maxLatency, avgLatency, successRate, testScenarios, testStartTimeStr);
  generateCSVReport(testScenarios, testStartTimeStr, testEndTimeStr);
}

async function generateExcelReport(rps, minLatency, maxLatency, avgLatency, successRate, testScenarios, testStartTimeStr) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'SmartMenu Performance Architect';
  workbook.created = new Date();

  // Color theme: Premium Deep Navy Blue & Muted Silver
  const headerFont = { name: 'Segoe UI', size: 11, bold: true, color: { argb: 'FFFFFF' } };
  const borderStyle = {
    top: { style: 'thin', color: { argb: 'D3D3D3' } },
    left: { style: 'thin', color: { argb: 'D3D3D3' } },
    bottom: { style: 'thin', color: { argb: 'D3D3D3' } },
    right: { style: 'thin', color: { argb: 'D3D3D3' } }
  };

  // Sheet 1 - Load Test Summary Dashboard
  const summarySheet = workbook.addWorksheet('Summary');
  summarySheet.views = [{ showGridLines: true }];
  
  // Format summary header title block
  summarySheet.mergeCells('B2:H2');
  const titleCell = summarySheet.getCell('B2');
  titleCell.value = 'SmartMenu API Performance Load Test Dashboard';
  titleCell.font = { name: 'Segoe UI', size: 16, bold: true, color: { argb: '1F497D' } };
  titleCell.alignment = { vertical: 'middle', horizontal: 'left' };
  
  summarySheet.getRow(2).height = 35;

  const summaryData = [
    ['Metric Description', 'Value'],
    ['Execution Timestamp', new Date().toLocaleString()],
    ['Target URL Under Test', targetUrl],
    ['Simulated Virtual Users (Concurrency)', `${concurrency} concurrent loops`],
    ['Test Target Duration', `${durationMs / 1000} seconds`],
    ['Total Transmitted Requests', totalRequests],
    ['HTTP Success Count (2xx Status)', successRequests],
    ['Network Failures / Timeouts / Non-2xx', failedRequests],
    ['Request Success Percentage', `${successRate.toFixed(2)}%`],
    ['Average Throughput (Requests/Sec)', `${rps.toFixed(2)} RPS`],
    ['Minimum Latency (Best Case)', `${minLatency} ms`],
    ['Maximum Latency (Worst Case)', `${maxLatency} ms`],
    ['Average Latency (Typical Response)', `${avgLatency.toFixed(2)} ms`]
  ];

  summaryData.forEach((row, idx) => {
    const rowNum = idx + 4;
    summarySheet.getCell(`B${rowNum}`).value = row[0];
    summarySheet.getCell(`C${rowNum}`).value = row[1];
    
    // Styling
    const cellB = summarySheet.getCell(`B${rowNum}`);
    const cellC = summarySheet.getCell(`C${rowNum}`);
    
    cellB.font = { name: 'Segoe UI', size: 10, bold: idx === 0 };
    cellC.font = { name: 'Segoe UI', size: 10, bold: idx === 0 };
    cellB.border = borderStyle;
    cellC.border = borderStyle;
    
    if (idx === 0) {
      cellB.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: '1F497D' } };
      cellB.font = headerFont;
      cellC.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: '1F497D' } };
      cellC.font = headerFont;
    } else {
      // Zebra striping
      if (idx % 2 === 0) {
        cellB.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'F2F5F8' } };
        cellC.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'F2F5F8' } };
      }
    }
  });

  summarySheet.getColumn('B').width = 40;
  summarySheet.getColumn('C').width = 35;

  // Sheet 2 - Test Scenario Benchmarks
  const testCasesSheet = workbook.addWorksheet('Test Cases');
  testCasesSheet.views = [{ showGridLines: true }];
  testCasesSheet.columns = [
    { header: 'Test ID', key: 'testId', width: 12 },
    { header: 'Module', key: 'module', width: 25 },
    { header: 'Scenario', key: 'scenario', width: 50 },
    { header: 'Device', key: 'device', width: 28 },
    { header: 'Status', key: 'status', width: 12 },
    { header: 'Duration (ms)', key: 'duration', width: 15 },
    { header: 'Failure Reason', key: 'reason', width: 50 }
  ];

  testScenarios.forEach((t) => {
    const row = testCasesSheet.addRow({
      testId: t.testId,
      module: t.module,
      scenario: t.scenario,
      device: t.device,
      status: t.status,
      duration: t.duration,
      reason: t.reason
    });

    // Color code Status cell
    const statusCell = row.getCell('status');
    if (t.status === 'Passed') {
      statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'E2EFDA' } };
      statusCell.font = { name: 'Segoe UI', bold: true, color: { argb: '375623' } };
    } else {
      statusCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FCE4D6' } };
      statusCell.font = { name: 'Segoe UI', bold: true, color: { argb: 'C65911' } };
    }

    row.eachCell((cell, colNumber) => {
      cell.border = borderStyle;
      if (colNumber !== 5) {
        cell.font = { name: 'Segoe UI', size: 10 };
      }
    });
  });

  testCasesSheet.getRow(1).height = 25;
  testCasesSheet.getRow(1).eachCell((cell) => {
    cell.font = headerFont;
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: '366092' } };
    cell.border = borderStyle;
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
  });

  // Sheet 3 - Step Logs
  const logsSheet = workbook.addWorksheet('Execution Logs');
  logsSheet.views = [{ showGridLines: true }];
  logsSheet.columns = [
    { header: 'Timestamp', key: 'timestamp', width: 25 },
    { header: 'Test Name', key: 'testName', width: 22 },
    { header: 'Step', key: 'step', width: 25 },
    { header: 'Result', key: 'result', width: 12 },
    { header: 'Remarks', key: 'remarks', width: 65 }
  ];

  logs.forEach((l) => {
    const row = logsSheet.addRow(l);
    row.eachCell((cell) => {
      cell.border = borderStyle;
      cell.font = { name: 'Segoe UI', size: 10 };
    });
  });

  logsSheet.getRow(1).height = 25;
  logsSheet.getRow(1).eachCell((cell) => {
    cell.font = headerFont;
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: '595959' } };
    cell.border = borderStyle;
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
  });

  // Ensure outputs are written to workspace root and local performance folder
  const rootExcelPath = path.resolve(__dirname, '../Load_Test_Report.xlsx');
  const perfExcelPath = path.resolve(__dirname, './Load_Test_Report.xlsx');

  await workbook.xlsx.writeFile(perfExcelPath);
  await workbook.xlsx.writeFile(rootExcelPath);
  logEvent('Teardown', 'Info', `Excel report generated successfully at: ${perfExcelPath}`);
  logEvent('Teardown', 'Info', `Excel report copied to workspace root at: ${rootExcelPath}`);
}

function generateCSVReport(testScenarios, testStartTimeStr, testEndTimeStr) {
  const rootCsvPath = path.resolve(__dirname, '../Load_Test_Report.csv');
  const perfCsvPath = path.resolve(__dirname, './Load_Test_Report.csv');

  let csvContent = 'Test ID,Module,Scenario,Device,Status,Start Time,End Time,Duration (ms),Failure Reason\n';
  
  testScenarios.forEach((t) => {
    const row = [
      t.testId,
      `"${t.module}"`,
      `"${t.scenario}"`,
      `"${t.device}"`,
      t.status,
      testStartTimeStr,
      testEndTimeStr,
      t.duration,
      `"${t.reason.replace(/"/g, '""')}"`
    ];
    csvContent += row.join(',') + '\n';
  });

  fs.writeFileSync(perfCsvPath, csvContent, 'utf8');
  fs.writeFileSync(rootCsvPath, csvContent, 'utf8');
  logEvent('Teardown', 'Info', `CSV report generated successfully at: ${perfCsvPath}`);
  logEvent('Teardown', 'Info', `CSV report copied to workspace root at: ${rootCsvPath}`);
}

// Run the script
run().catch((err) => {
  logEvent('Execution', 'Error', `Fatal error during load test run: ${err.message}`);
  process.exit(1);
});
