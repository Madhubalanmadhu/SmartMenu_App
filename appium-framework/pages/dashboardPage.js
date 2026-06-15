const BasePage = require('./basePage');
const logger = require('../utilities/logger');

class DashboardPage extends BasePage {
  constructor(driver) {
    super(driver);
    
    // Bottom tabs layout (Y = 0.96)
    this.tabY = 0.96;
    this.tabs = {
      dashboard: 0.1,
      menu: 0.3,
      sales: 0.5,
      analytics: 0.7,
      waste: 0.9
    };

    // Sales module elements
    this.enterSalesCardRatio = { x: 0.25, y: 0.45 };
    this.salesDateRatio = { x: 0.5, y: 0.40 };
    this.salesDishDropdownRatio = { x: 0.5, y: 0.50 };
    this.salesQtyRatio = { x: 0.5, y: 0.60 };
    this.saveSaleButtonRatio = { x: 0.65, y: 0.72 };

    // Logout coordinates (usually via side drawer or top bar menu)
    this.menuDrawerRatio = { x: 0.06, y: 0.06 };
    this.logoutMenuItemRatio = { x: 0.3, y: 0.92 }; // Logout is typically at the bottom of the drawer
  }

  async navigateToTab(tabName) {
    const tabXRatio = this.tabs[tabName.toLowerCase()];
    if (tabXRatio === undefined) {
      throw new Error(`Invalid tab name: ${tabName}`);
    }
    logger.info(`Navigating to tab: ${tabName}`);
    await this.tapRatio(tabXRatio, this.tabY);
    await this.sleep(3000);
  }

  async openSalesDialog() {
    logger.info('Opening Sales record entry dialog');
    await this.navigateToTab('Sales');
    await this.tapRatio(this.enterSalesCardRatio.x, this.enterSalesCardRatio.y);
    await this.sleep(2000);
  }

  async recordSale(date, quantity) {
    logger.info(`Recording sale: Date=${date}, Qty=${quantity}`);
    
    // Enter date
    await this.tapRatio(this.salesDateRatio.x, this.salesDateRatio.y);
    // Select all and clear
    const actions = this.driver.actions();
    await actions.sendKeys(date).perform();
    await this.sleep(1000);

    // Click dropdown, send down arrow and enter
    await this.tapRatio(this.salesDishDropdownRatio.x, this.salesDishDropdownRatio.y);
    await this.sleep(1000);
    await this.driver.actions().sendKeys('\uE015').sendKeys('\uE006').perform(); // Arrow Down + Enter
    await this.sleep(1000);

    // Enter quantity
    await this.tapRatio(this.salesQtyRatio.x, this.salesQtyRatio.y);
    await this.driver.actions().sendKeys(quantity).perform();
    await this.sleep(1000);

    // Click save
    await this.tapRatio(this.saveSaleButtonRatio.x, this.saveSaleButtonRatio.y);
    await this.sleep(4000);
  }

  async logout() {
    logger.info('Performing logout sequence');
    // Open drawer
    await this.tapRatio(this.menuDrawerRatio.x, this.menuDrawerRatio.y);
    await this.sleep(1500);
    // Click logout
    await this.tapRatio(this.logoutMenuItemRatio.x, this.logoutMenuItemRatio.y);
    await this.sleep(3000);
  }
}

module.exports = DashboardPage;
