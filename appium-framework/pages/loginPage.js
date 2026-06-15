const BasePage = require('./basePage');
const logger = require('../utilities/logger');

class LoginPage extends BasePage {
  constructor(driver) {
    super(driver);
    // Elements coordinate ratios derived from viewport measurements
    this.emailRatio = { x: 0.35, y: 0.62 };
    this.passwordRatio = { x: 0.35, y: 0.72 };
    this.loginButtonRatio = { x: 0.35, y: 0.83 };
  }

  async enterEmail(email) {
    logger.info(`Entering email: ${email}`);
    await this.sendKeysToRatio(this.emailRatio.x, this.emailRatio.y, email);
  }

  async enterPassword(password) {
    logger.info('Entering password');
    await this.sendKeysToRatio(this.passwordRatio.x, this.passwordRatio.y, password);
  }

  async clickLogin() {
    logger.info('Tapping login button');
    await this.tapRatio(this.loginButtonRatio.x, this.loginButtonRatio.y);
    await this.sleep(5000); // Allow transition animation or network request
  }

  async login(email, password) {
    await this.enterEmail(email);
    await this.enterPassword(password);
    await this.clickLogin();
  }

  async clearInputs() {
    logger.info('Clearing login inputs');
    await this.clearField(this.emailRatio.x, this.emailRatio.y);
    await this.clearField(this.passwordRatio.x, this.passwordRatio.y);
  }
}

module.exports = LoginPage;
