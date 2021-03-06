/**
 * @author sfount
 * @version 0.9.0
 * @date 30/08/2018
 * @description
 * - Performance improvements for `GenerateTransactionID()` SQL method
 * - Added additional transaction ID column to the `posting_journal`
 *   and `general_ledger` tables
 * - Added additional index to `posting_journal` and `general_ledger` tables
**/

-- SQL Function delimiter definition
DELIMITER $$ -- Add integer reference numbers to posting journal and general ledger
ALTER TABLE posting_journal
  ADD COLUMN trans_id_reference_number MEDIUMINT UNSIGNED NOT NULL,
  ADD INDEX (trans_id_reference_number);

ALTER TABLE general_ledger
  ADD COLUMN trans_id_reference_number MEDIUMINT UNSIGNED NOT NULL,
  ADD INDEX (trans_id_reference_number);

-- Populate new reference numbers using the existing String equivalent
UPDATE posting_journal SET trans_id_reference_number = SUBSTR(trans_id, 4);
UPDATE general_ledger SET trans_id_reference_number = SUBSTR(trans_id, 4);

-- Remove the current implementation of `GenerateTransactionId`
DROP FUNCTION GenerateTransactionId;

-- Implement the improved performance `GenerateTransactionId` function
-- (note_ the API will not change)
-- (note_ SUBSELECT vs. JOIN was tested, SUBSELECT was used because it works when there are no rows in journals
CREATE FUNCTION GenerateTransactionId(
  target_project_id SMALLINT(5)
)
RETURNS VARCHAR(100) DETERMINISTIC
BEGIN
  RETURN (
    SELECT CONCAT(
      (SELECT abbr AS project_string FROM project WHERE id = target_project_id),
      IFNULL(MAX(current_max) + 1, 1)
    ) AS id
    FROM (
      (
        SELECT trans_id_reference_number AS current_max
        FROM general_ledger
        WHERE project_id = target_project_id
        ORDER BY trans_id_reference_number DESC
        LIMIT 1
      )
      UNION
      (
        SELECT trans_id_reference_number AS current_max FROM posting_journal
        WHERE project_id = target_project_id
        ORDER BY trans_id_reference_number DESC
        LIMIT 1
      )
    )A
  );
END $$

-- Last updated 30/08/2018 23:53 @sfount

/*
@author jniles

@description
This file removes the previous version of the BUID() function, which was slow
and cumbersome, and replaces it with a faster version of itself.
*/

DELIMITER $$

DROP FUNCTION IF EXISTS BUID;

CREATE FUNCTION BUID(b BINARY(16))
RETURNS CHAR(32) DETERMINISTIC
BEGIN
  RETURN HEX(b);
END
$$

DELIMITER ;

/*
@author mbayopanda
@description adds the OHADA Bilan to the navigation tree.
*/
INSERT IGNORE INTO unit VALUES
  (206, '[OHADA] Bilan','TREE.OHADA_BALANCE_SHEET','',144,'/modules/reports/ohada_balance_sheet_report','/reports/ohada_balance_sheet_report');

/* Record the report */
INSERT IGNORE INTO `report` (`id`, `report_key`, `title_key`) VALUES
  (20, 'ohada_balance_sheet_report', 'REPORT.OHADA.BALANCE_SHEET');

/*
@author mbayopanda

@description
  ACCOUNT REFERENCE MODULE AND REPORT
  ===================================
  NOTE : Please create `account_reference` and `account_reference_item` tables first
*/


DROP TABLE IF EXISTS `account_reference_item`;
DROP TABLE IF EXISTS `account_reference`;

CREATE TABLE `account_reference` (
  `id` MEDIUMINT(8) UNSIGNED NOT NULL AUTO_INCREMENT,
  `abbr` VARCHAR(35) NOT NULL,
  `description` VARCHAR(100) NOT NULL,
  `parent` MEDIUMINT(8) UNSIGNED NULL,
  `is_amo_dep` TINYINT(1) NULL DEFAULT 0 COMMENT 'Ammortissement or depreciation',
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_reference_1` (`abbr`, `is_amo_dep`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `account_reference_item` (
  `id` MEDIUMINT(8) UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_reference_id` MEDIUMINT(8) UNSIGNED NOT NULL,
  `account_id` INT(10) UNSIGNED NOT NULL,
  `is_exception` TINYINT(1) NULL DEFAULT 0 COMMENT 'Except this for reference calculation',
  PRIMARY KEY (`id`),
  KEY `account_reference_id` (`account_reference_id`),
  KEY `account_id` (`account_id`),
  FOREIGN KEY (`account_reference_id`) REFERENCES `account_reference` (`id`),
  FOREIGN KEY (`account_id`) REFERENCES `account` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO unit VALUES
  (205, 'Account Reference Management','TREE.ACCOUNT_REFERENCE_MANAGEMENT','',1,'/modules/account_reference','/account_reference'),
  (206, '[OHADA] Bilan','TREE.OHADA_BALANCE_SHEET','',144,'/modules/reports/ohada_balance_sheet_report','/reports/ohada_balance_sheet_report'),
  (207, 'Account Reference Report','TREE.ACCOUNT_REFERENCE_REPORT','',144,'/modules/reports/account_reference','/reports/account_reference');

INSERT IGNORE INTO `report` (`id`, `report_key`, `title_key`) VALUES
  (20, 'ohada_balance_sheet_report', 'REPORT.OHADA.BALANCE_SHEET'),
  (21, 'account_reference', 'REPORT.ACCOUNT_REFERENCE.TITLE');


/*
@author jniles
@description
  UPDATE ENTERPRISE_SETTING TABLE
  ===============================

  ADD BALANCE ON INVOICE RECEIPT OPTION
  If yes, the balance will be displayed on the invoice as proof.
*/

ALTER TABLE `enterprise_setting` ADD COLUMN `enable_balance_on_invoice_receipt` TINYINT(1) NOT NULL DEFAULT 1;

/*
@author jniles
@description
Add stock accounting to the enterprise settings
*/

ALTER TABLE `enterprise_setting` ADD COLUMN `enable_auto_stock_accounting` TINYINT(1) NOT NULL DEFAULT 1;

/*
@author jniles
@description
Add enable barcodes setting to the enterprise settings
*/
ALTER TABLE `enterprise_setting` ADD COLUMN `enable_barcodes` TINYINT(1) NOT NULL DEFAULT 1;

/*
@author bruce
@description
Add stock import module in the navigation tree
*/
INSERT IGNORE INTO unit VALUES
(208, 'Import Stock From File','TREE.IMPORT_STOCK_FROM_FILE','',160,'/modules/stock/import','/stock/import');

/*
@author bruce
@description
Add created_at column in stock_movement for having the true date
*/
ALTER TABLE `stock_movement` ADD COLUMN `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;


/*
@author bruce
@description
This procedure add missing stock movement reference inside the table document_map
it fixes the problem of nothing as reference in the stock movement registry
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS AddMissingMovementReference$$
CREATE PROCEDURE AddMissingMovementReference()
BEGIN
  -- declaration
  DECLARE v_document_uuid BINARY(16);
  DECLARE v_reference INT(11);

  -- cursor variable declaration
  DECLARE v_finished INTEGER DEFAULT 0;

  -- cursor declaration
  DECLARE stage_missing_movement_document_cursor CURSOR FOR
  	SELECT temp.document_uuid
	FROM missing_movement_document as temp;

  -- variables for the cursor
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;

  -- temporary table for movement which doesn't have movement reference identifier
  DROP TABLE IF EXISTS missing_movement_document;

  CREATE TEMPORARY TABLE missing_movement_document (
    SELECT m.document_uuid FROM stock_movement m
    LEFT JOIN document_map dm ON dm.uuid IS NULL
    GROUP BY m.document_uuid
  );

  -- open the cursor
  OPEN stage_missing_movement_document_cursor;

  -- loop inside the cursor
  missing_document : LOOP

    /* fetch data into variables */
    FETCH stage_missing_movement_document_cursor INTO v_document_uuid;

    IF v_finished = 1 THEN
      LEAVE missing_document;
    END IF;

    CALL ComputeMovementReference(v_document_uuid);

  END LOOP missing_document;

  -- close the cursor
  CLOSE stage_missing_movement_document_cursor;

  DROP TEMPORARY TABLE missing_movement_document;
END $$

/*
PROCEDURE UnbalancedInvoicePayments

USAGE: Call UnbalancedInvoicePayments(dateFrom, dateTo);

Description:
This SP retrieves the balance of invoices made during a period of time.  It
filters out invoices that are reversed (they should be balanced by default),
as well as balanced invoices.

*/
DROP PROCEDURE IF EXISTS UnbalancedInvoicePayments$$
CREATE PROCEDURE UnbalancedInvoicePayments(
  IN dateFrom DATE,
  IN dateTo DATE
) BEGIN

  -- this holds all the invoices that were made during the period
  -- two copies are needed for the UNION ALL query.
  DROP TABLE IF EXISTS tmp_invoices_1;
  CREATE TABLE tmp_invoices_1 (INDEX uuid (uuid)) AS
    SELECT invoice.uuid, invoice.debtor_uuid, invoice.date
    FROM invoice
    WHERE
      DATE(invoice.date) BETWEEN DATE(dateFrom) AND DATE(dateTo)
      AND reversed = 0
    ORDER BY invoice.date;

  DROP TABLE IF EXISTS tmp_invoices_2;
  CREATE TABLE tmp_invoices_2 AS SELECT * FROM tmp_invoices_1;

  -- This holds the invoices from the PJ/GL
  DROP TABLE IF EXISTS tmp_records;
  CREATE TABLE tmp_records AS
    SELECT ledger.record_uuid AS uuid, ledger.debit_equiv, ledger.credit_equiv
    FROM (
      SELECT pj.record_uuid, pj.debit_equiv, pj.credit_equiv
      FROM posting_journal pj
        JOIN tmp_invoices_1 i ON i.uuid = pj.record_uuid
          AND pj.entity_uuid = i.debtor_uuid

      UNION ALL

      SELECT gl.record_uuid, gl.debit_equiv, gl.credit_equiv
      FROM general_ledger gl
        JOIN tmp_invoices_2 i ON i.uuid = gl.record_uuid
            AND gl.entity_uuid = i.debtor_uuid
  ) AS ledger;

  -- this holds the references/payments against the invoices
  DROP TABLE IF EXISTS tmp_references;
  CREATE TABLE tmp_references AS
    SELECT ledger.reference_uuid AS uuid, ledger.debit_equiv, ledger.credit_equiv
    FROM (
      SELECT pj.reference_uuid, pj.debit_equiv, pj.credit_equiv
      FROM posting_journal pj
        JOIN tmp_invoices_1 i ON i.uuid = pj.reference_uuid
          AND pj.entity_uuid = i.debtor_uuid

      UNION ALL

      SELECT gl.reference_uuid, gl.debit_equiv, gl.credit_equiv
      FROM general_ledger gl
        JOIN tmp_invoices_2 i ON i.uuid = gl.reference_uuid
          AND gl.entity_uuid = i.debtor_uuid
  ) AS ledger;

  -- combine invoices and references to get the balance of each invoice.
  -- note that we filter out balanced invoices
  DROP TABLE IF EXISTS tmp_invoice_balances;
  CREATE TABLE tmp_invoice_balances AS
    SELECT z.uuid, SUM(z.debit_equiv) AS debit_equiv,
      SUM(z.credit_equiv) AS credit_equiv,
      SUM(z.debit_equiv) - SUM(z.credit_equiv) AS balance
    FROM (
      SELECT i.uuid, i.debit_equiv, i.credit_equiv FROM tmp_records i
      UNION ALL
      SELECT p.uuid, p.debit_equiv, p.credit_equiv FROM tmp_references p
    )z
    GROUP BY z.uuid
    HAVING balance <> 0;

  -- even though this column is called "balance", it is actually the amount remaining
  -- on the invoice.
  SELECT BUID(iv.debtor_uuid) AS debtor_uuid, balances.debit_equiv AS debit,
    balances.credit_equiv AS credit, iv.date AS creation_date, balances.balance,
    IFNULL(balances.credit_equiv / balances.debit_equiv, 0) AS paymentPercentage,
    dm.text AS reference
  FROM tmp_invoices_1 AS iv
    JOIN tmp_invoice_balances AS balances ON iv.uuid = balances.uuid
    LEFT JOIN document_map AS dm ON dm.uuid = iv.uuid
    JOIN debtor ON debtor.uuid = iv.debtor_uuid
    LEFT JOIN entity_map AS em ON em.uuid = iv.debtor_uuid
  ORDER BY iv.date;
END$$

DELIMITER ;

INSERT INTO `report` (`report_key`, `title_key`) VALUES
  ('income_expense_by_month', 'REPORT.INCOME_EXPENSE_BY_MONTH'),
  ('unbalanced_invoice_payments_report', 'REPORT.UNBALANCED_INVOICE_PAYMENTS_REPORT.TITLE'),
  ('account_report_multiple', 'REPORT.REPORT_ACCOUNTS_MULTIPLE.TITLE');

INSERT INTO `unit` VALUES
  (211, 'Income Expenses by month', 'TREE.INCOME_EXPENSE_BY_MONTH', 'The Report of income and expenses', 144, '/modules/finance/income_expense_by_month', '/reports/income_expense_by_month'),
  (212, 'Accounts Report multiple','TREE.REPORTS_MULTIPLE_ACCOUNTS','',144,'/modules/reports/account_report_multiple','/reports/account_report_multiple');
  (213, 'unbalanced invoice payments','REPORT.UNBALANCED_INVOICE_PAYMENTS_REPORT.TITLE','',144,'/modules/reports/unbalanced_invoice_payments_report','/reports/unbalanced_invoice_payments_report');

/*
@author jniles
@description
Fix reference_uuid index bug
@date 2018-10-02
*/
ALTER TABLE `general_ledger` DROP INDEX `reference_uuid`;
ALTER TABLE `posting_journal` DROP INDEX `reference_uuid`;
ALTER TABLE `posting_journal` ADD INDEX `reference_uuid` (`reference_uuid`);
ALTER TABLE `general_ledger` ADD INDEX `reference_uuid` (`reference_uuid`);





INSERT INTO unit VALUES
(210, 'Stock value Report','TREE.STOCK_VALUE','',144,'/modules/reports/stock_value','/reports/stock_value');

INSERT INTO `report` (`id`, `report_key`, `title_key`) 
VALUES  (23, 'stock_value', 'TREE.STOCK_VALUE');


DELIMITER $$
/* report for stock movement */
/* retrieve the stock status( current qtt, unit_cost, value)for a specific inventory in a depot */

DROP PROCEDURE IF EXISTS `stockInventoryReport`$$
CREATE PROCEDURE `stockInventoryReport`(IN _inventory_uuid BINARY(16), IN  _depot_uuid BINARY(16), IN _dateTo DATE)
BEGIN
  DECLARE done BOOLEAN;
  DECLARE mvtIsExit, mvtQtt,  mvtUnitCost, mvtValue DECIMAL(19, 4);
  DECLARE newQuantity, newValue, newCost DECIMAL(19, 4);
  DECLARE stockQtt, stockUnitCost, stockValue DECIMAL(19, 4);
  DECLARE _documentReference VARCHAR(100);
  DECLARE _date DATETIME;

  DECLARE curs1 CURSOR FOR 
    SELECT DISTINCT m.is_exit, l.unit_cost, m.quantity, m.date, dm.text AS documentReference
    FROM stock_movement m
    JOIN lot l ON l.uuid = m.lot_uuid
    JOIN inventory i ON i.uuid = l.inventory_uuid
    JOIN inventory_unit iu ON iu.id = i.unit_id
    JOIN depot d ON d.uuid = m.depot_uuid
    LEFT JOIN document_map dm ON dm.uuid = m.document_uuid
    WHERE i.uuid = _inventory_uuid AND m.depot_uuid = _depot_uuid AND DATE(m.date) <= _dateTo
    ORDER BY m.created_at ASC;
      
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  DROP TEMPORARY TABLE IF EXISTS stage_movement;
  CREATE TEMPORARY TABLE stage_movement(
    isExit TINYINT(1),
    qtt DECIMAL(19, 4),
    unit_cost DECIMAL(19, 4),
    value DECIMAL(19, 4),
    date DATETIME,
    reference VARCHAR(100),
    stockQtt DECIMAL(19, 4),
    stockUnitCost DECIMAL(19, 4),
    stockValue DECIMAL(19, 4)
  );

  SET stockQtt= 0;
  SET stockUnitCost = 0;
  SET stockValue = 0;

  OPEN curs1;
    read_loop: LOOP
    
    SET mvtIsExit = 0;
    SET mvtQtt = 0;
    SET mvtUnitCost = 0;
    SET mvtValue = 0;
    SET newQuantity = 0;
    SET newValue = 0;
    SET newCost = 0;
    
    FETCH curs1 INTO mvtIsExit, mvtUnitCost, mvtQtt, _date, _documentReference;
      IF done THEN
        LEAVE read_loop;
      END IF;

      IF mvtIsExit = 1 THEN
        SET stockQtt = stockQtt - mvtQtt;
        SET stockValue = stockQtt * stockUnitCost;
      ELSE
	      SET newQuantity = mvtQtt + stockQtt;
        SET newValue = (mvtUnitCost * mvtQtt) + stockValue;
        SET newCost = newValue / IF(newQuantity = 0, 1, newQuantity);

        SET stockQtt = newQuantity;
        SET stockUnitCost = newCost;
        SET stockValue = newValue;         
      END IF;
       
      INSERT INTO stage_movement VALUES(
        mvtIsExit, mvtQtt, stockQtt, mvtQtt*mvtUnitCost, _date, _documentReference,  stockQtt, stockUnitCost, stockValue
      );
    END LOOP;
CLOSE curs1;

SELECT  * FROM stage_movement;

END$$


/*   retrieve the stock status( current qtt, unit_cost, value) for each inventory in a depot */
DROP PROCEDURE IF EXISTS `stockValue`$$

CREATE PROCEDURE `stockValue`(IN _depot_uuid BINARY(16), IN _dateTo DATE)
BEGIN
  DECLARE done BOOLEAN;
  DECLARE mvtIsExit, mvtQtt,  mvtUnitCost, mvtValue DECIMAL(19, 4);
  DECLARE newQuantity, newValue, newCost DECIMAL(19, 4);
  DECLARE stockQtt, stockUnitCost, stockValue DECIMAL(19, 4);
  DECLARE _documentReference VARCHAR(100);
  DECLARE _date DATETIME;
  DECLARE _inventory_uuid BINARY(16);
  DECLARE _iteration, _newStock INT;
  
  
  DECLARE curs1 CURSOR FOR 
    SELECT DISTINCT i.uuid, m.is_exit, l.unit_cost, m.quantity, m.date, dm.text AS documentReference
    FROM stock_movement m
    JOIN lot l ON l.uuid = m.lot_uuid
    JOIN inventory i ON i.uuid = l.inventory_uuid
    JOIN inventory_unit iu ON iu.id = i.unit_id
    JOIN depot d ON d.uuid = m.depot_uuid
    LEFT JOIN document_map dm ON dm.uuid = m.document_uuid
    WHERE m.depot_uuid = _depot_uuid AND DATE(m.date) <= _dateTo
    ORDER BY i.text, m.created_at ASC;
      
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  DROP TEMPORARY TABLE IF EXISTS stage_movement;
  CREATE TEMPORARY TABLE stage_movement(
    inventory_uuid BINARY(16),
    isExit TINYINT(1),
    qtt DECIMAL(19, 4),
    unit_cost DECIMAL(19, 4),
    VALUE DECIMAL(19, 4),
    DATE DATETIME,
    reference VARCHAR(100),
    stockQtt DECIMAL(19, 4),
    stockUnitCost DECIMAL(19, 4),
    stockValue DECIMAL(19, 4),
    iteration INT
  );


  OPEN curs1;
    read_loop: LOOP
    
    SET mvtIsExit = 0;
    SET mvtQtt = 0;
    SET mvtUnitCost = 0;
    SET mvtValue = 0;
    SET newQuantity = 0;
    SET newValue = 0;
    SET newCost = 0;
    
    FETCH curs1 INTO _inventory_uuid, mvtIsExit, mvtUnitCost, mvtQtt, _date, _documentReference;
      IF done THEN
        LEAVE read_loop;
      END IF;
      
      SELECT COUNT(inventory_uuid) INTO _newStock FROM stage_movement WHERE inventory_uuid = _inventory_uuid;
      -- set stock qtt, value and unit cost for a new inventory
      IF _newStock = 0 THEN 
        SET stockQtt= 0;
        SET stockUnitCost = 0;
        SET stockValue = 0;
        SET _iteration = 0; 
      END IF;

      -- stock exit movement, the stock quantity decreases
      IF mvtIsExit = 1 THEN
        SET stockQtt = stockQtt - mvtQtt;
        SET stockValue = stockQtt * stockUnitCost;
      ELSE
       -- stock exit movement, the stock quantity increases
	      SET newQuantity = mvtQtt + stockQtt;
        SET newValue = (mvtUnitCost * mvtQtt) + stockValue;
        SET newCost = newValue / IF(newQuantity = 0, 1, newQuantity);

        SET stockQtt = newQuantity;
        SET stockUnitCost = newCost;
        SET stockValue = newValue;         
      END IF;
       
      INSERT INTO stage_movement VALUES(
        _inventory_uuid, mvtIsExit, mvtQtt, stockQtt, mvtQtt*mvtUnitCost, _date, _documentReference,  stockQtt, stockUnitCost, stockValue, _iteration
      );
      SET _iteration = _iteration + 1;
    END LOOP;
  CLOSE curs1;

  DROP TEMPORARY TABLE IF EXISTS stage_movement_copy;
  CREATE TEMPORARY TABLE stage_movement_copy AS SELECT * FROM stage_movement;

  -- inventory stock
  SELECT  BUID(sm.inventory_uuid) AS inventory_uuid, i.text as inventory_name,  sm.stockQtt, sm.stockUnitCost, sm.stockValue
  FROM stage_movement sm
  JOIN inventory i ON i.uuid = sm.inventory_uuid
  INNER JOIN (
    SELECT inventory_uuid, MAX(iteration) as max_iteration
    FROM stage_movement_copy
    GROUP BY inventory_uuid
  )x ON x.inventory_uuid = sm.inventory_uuid AND x.max_iteration = sm.iteration

  ORDER BY i.text ASC;

  -- total in stock
  SELECT SUM(sm.stockValue) as total
  FROM stage_movement as sm
  INNER JOIN (
    SELECT inventory_uuid, MAX(iteration) as max_iteration
    FROM stage_movement_copy
    GROUP BY inventory_uuid
  )x ON x.inventory_uuid = sm.inventory_uuid AND x.max_iteration = sm.iteration;

END$$

DELIMITER ;
