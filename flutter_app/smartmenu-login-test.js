const fs = require('fs');
const { Builder } = require('selenium-webdriver');

const WEB_APP_URL = 'http://127.0.0.1:50379';
const TEST_EMAIL = 'madhuhawk774@gmail.com';
const TEST_PASSWORD = 'ikmdmad7';

async function clickAt(driver, x, y) {
  await driver.executeScript(
    `
      const el = document.elementFromPoint(arguments[0], arguments[1]);
      if (el) el.click();
    `,
    x,
    y
  );
}

async function testSmartMenu() {
  const driver = await new Builder().forBrowser('chrome').build();

  try {
    await driver.manage().window().setRect({ width: 1000, height: 1000 });
    await driver.get(WEB_APP_URL);

    await driver.sleep(5000);

    const size = await driver.executeScript(`
      return { width: window.innerWidth, height: window.innerHeight };
    `);

    console.log('Viewport:', size);

    const x = Math.floor(size.width * 0.35);
    const emailY = Math.floor(size.height * 0.62);
    const passwordY = Math.floor(size.height * 0.72);
    const buttonY = Math.floor(size.height * 0.83);

    await clickAt(driver, x, emailY);
    await driver.actions().sendKeys(TEST_EMAIL).perform();

    await clickAt(driver, x, passwordY);
    await driver.actions().sendKeys(TEST_PASSWORD).perform();

    await clickAt(driver, x, buttonY);

    await driver.sleep(8000);

    fs.writeFileSync(
      'after-login.png',
      await driver.takeScreenshot(),
      'base64'
    );

    console.log('Login test clicked through');
    console.log('Screenshot saved as after-login.png');
  } catch (error) {
    console.log(error);
  } finally {
    await driver.quit();
  }
}

testSmartMenu();