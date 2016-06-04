CREATE OR REPLACE PACKAGE Pkg_FSS_Settlement AS
  PROCEDURE UploadNewTransactions;
  FUNCTION CheckRunTable(p_runid NUMBER) RETURN BOOLEAN;
  FUNCTION CreateRunTableEntry RETURN NUMBER;
  PROCEDURE AnnounceMe(p_module_name VARCHAR2, p_destination VARCHAR2 DEFAULT 'T');
  PROCEDURE DailySettlement;
  PROCEDURE WriteDeskbankHeader(
    p_file_name VARCHAR2,
    p_organisation_accounttitle VARCHAR2,
    p_organisation_bsb VARCHAR2
  );
  PROCEDURE WriteDeskbankFooter(
    p_file_name VARCHAR2,
    p_file_total NUMBER,
    p_credit_total NUMBER,
    p_debit_total NUMBER,
    p_record_count NUMBER
  );
  PROCEDURE WriteToFile(p_directory VARCHAR2, p_file_name VARCHAR2, p_line VARCHAR2);
  FUNCTION DateToTimestamp(p_date DATE DEFAULT sysdate) RETURN NUMBER;
  PROCEDURE UpdateRunTableEntry(p_runid NUMBER, p_runoutcome VARCHAR2, p_remarks VARCHAR2 DEFAULT 'N/A');
  FUNCTION GetParameter(p_kind VARCHAR2, p_code VARCHAR2) RETURN VARCHAR2;
  FUNCTION GetReference(p_id VARCHAR2) RETURN VARCHAR2;
  PROCEDURE WriteDeskbankRecord(p_file_name VARCHAR2,
    p_bsb VARCHAR2,
    p_accountnr VARCHAR2,
    p_transactioncode NUMBER,
    p_value NUMBER,
    p_merchanttitle VARCHAR2,
    p_bankflag VARCHAR2,
    p_lodgementnr VARCHAR2
  );
  FUNCTION ConvertDollarsToCents(p_dollars FLOAT) RETURN NUMBER;
  FUNCTION ConvertCentsToDollars(p_cents NUMBER) RETURN VARCHAR2;
  PROCEDURE SettleTransactions(p_file_name VARCHAR2);
  FUNCTION CreateTransactionSequence RETURN VARCHAR2;
  PROCEDURE UpdateDailyTransactions(p_merchantid VARCHAR2, p_transaction_seq VARCHAR2);
  PROCEDURE CreateSettlementRecord(
    p_bsb VARCHAR2,
    p_accountnr VARCHAR2,
    p_transactioncode NUMBER,
    p_settlevalue NUMBER,
    p_merchantid NUMBER,
    p_merchanttitle VARCHAR2,
    p_bankflag VARCHAR2,
    p_lodgementnr VARCHAR2
  );
  FUNCTION GetMinimumSettlement RETURN NUMBER;
  FUNCTION GetAmountToSettle(p_minimum_settlement NUMBER) RETURN NUMBER;
  PROCEDURE WriteOrganisationRecord(p_file_name VARCHAR2,
    p_debit_total NUMBER,
    p_organisation_bsb VARCHAR2,
    p_organisation_accountnr VARCHAR2,
    p_organisation_accounttitle VARCHAR2,
    p_organisation_id VARCHAR2
  );
  FUNCTION FormatBSB(p_bsb VARCHAR2) RETURN VARCHAR2;
  PROCEDURE DailyBankingSummary(p_report_date VARCHAR2 DEFAULT to_char(sysdate, 'DD-MON-YYYY'));
  PROCEDURE FraudReport;
  PROCEDURE ClearFile(p_directory VARCHAR2, p_file VARCHAR2);
  PROCEDURE WriteFraudReportRecord(p_dir VARCHAR2, p_file VARCHAR2, p_cardid VARCHAR2, p_transactionnr NUMBER);
END Pkg_FSS_Settlement;