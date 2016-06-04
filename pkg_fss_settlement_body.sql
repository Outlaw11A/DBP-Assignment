CREATE OR REPLACE PACKAGE BODY Pkg_FSS_Settlement as

  PROCEDURE FraudReport IS
    /**
      Purpose: Creates the fraud report
      Author: Alexander Price, 11995483
      Date: 26/05/2016
     */
    v_module_name VARCHAR2(35) := 'FraudReport';
    CURSOR c_cards IS
      SELECT CARDID
      FROM fss_daily_transaction
      GROUP BY CARDID;
    CURSOR c_card_detail (p_cardid IN NUMBER) IS
      SELECT
        TRANSACTIONNR,
        CARDOLDVALUE,
        CARDNEWVALUE
      FROM fss_daily_transaction
      WHERE CARDID = p_cardid
      ORDER BY TRANSACTIONDATE;
    v_previous_transaction_id NUMBER := NULL;
    v_previous_new_value NUMBER := NULL;
    v_directory_name VARCHAR2(35) := GetParameter('DIRECTORY', 'OUTPUT_DIRECTORY');
    v_file_name VARCHAR2(19) := 'FR_' || to_char(to_date(sysdate), 'DDMMYYYY') || '_AWP.dat';
    BEGIN
      AnnounceMe(v_module_name);
      ClearFile(v_directory_name, v_file_name);
      WriteToFile(v_directory_name, v_file_name, LPAD(' ', 30, ' ') || 'SMARTCARD SETTLEMENT SYSTEM');
      WriteToFile(v_directory_name, v_file_name, LPAD(' ', 39, ' ') || '      FRAUD REPORT');
      WriteToFile(v_directory_name, v_file_name, 'Date ' || to_char(sysdate, 'DD-MON-YYYY'));
      WriteToFile(v_directory_name, v_file_name, 'Status            Transaction NR  Card ID            Download Date  Terminal ID  Old Amount  Value    New Amount  Transaction SEQ');
      WriteToFile(v_directory_name, v_file_name, '----------------  --------------  -----------------  -------------  -----------  ----------  -------  ----------  ---------------');
      FOR r_card IN c_cards
        LOOP
          FOR r_card_detail IN c_card_detail(r_card.CARDID)
            LOOP
              IF v_previous_transaction_id IS NOT NULL THEN
                IF v_previous_new_value != r_card_detail.CARDOLDVALUE THEN
                  WriteFraudReportRecord(v_directory_name, v_file_name, r_card.CARDID, r_card_detail.TRANSACTIONNR);
                  EXIT;
                END IF;
              END IF;
              v_previous_transaction_id := r_card_detail.TRANSACTIONNR;
              v_previous_new_value := r_card_detail.CARDNEWVALUE;
          END LOOP;
          v_previous_transaction_id := NULL;
          v_previous_new_value := NULL;
      END LOOP;
      WriteToFile(v_directory_name, v_file_name, LPAD('-', 129, '-'));
      WriteToFile(v_directory_name, v_file_name, ' ');
      WriteToFile(v_directory_name, v_file_name, ' ');
      WriteToFile(v_directory_name, v_file_name, 'Dispatch Date      : ' || to_char(to_date(sysdate), 'DD Mon YYYY'));
      WriteToFile(v_directory_name, v_file_name, LPAD(' ', 41, ' ') || '***** End of Report *****');
    END;

  PROCEDURE WriteFraudReportRecord(p_dir VARCHAR2, p_file VARCHAR2, p_cardid VARCHAR2, p_transactionnr NUMBER) IS
    /**
      Purpose: Writes out the transaction details for a fraudulant card
      Author: Alexander Price, 11995483
      Date: 26/05/2016
     */
    v_module_name VARCHAR2(35) := 'WriteFraudReportRecord';
    CURSOR c_card_transactions IS
      SELECT
        TRANSACTIONNR,
        DOWNLOADDATE,
        TERMINALID,
        CARDOLDVALUE,
        CARDNEWVALUE,
        TRANSACTIONSEQ,
        TRANSACTIONAMOUNT
      FROM fss_daily_transaction
      WHERE CARDID = p_cardid
      ORDER BY TRANSACTIONDATE;
    v_fraud_match BOOLEAN := FALSE;
    v_output_string VARCHAR2(120) := '';
    BEGIN
      AnnounceMe(v_module_name);
      FOR r_transaction IN c_card_transactions
        LOOP
          IF p_transactionnr = r_transaction.TRANSACTIONNR THEN
            v_fraud_match := TRUE;
            v_output_string := 'FRAUD DETECTED > ';
          ELSEIF v_fraud_match = TRUE THEN
            v_output_string := RPAD(' ', 15, ' ') || '>';
          ELSE
            v_output_string := RPAD(' ', 16, ' ');
          END IF;
          v_output_string := v_output_string
                             || '  '
                             || LPAD(r_transaction.TRANSACTIONNR, 16, ' ')
                             || '  '
                             || p_cardid
                             || '  '
                             || LPAD(r_transaction.DOWNLOADDATE, 13, ' ')
                             || '  '
                             || LPAD(r_transaction.TERMINALID, 11, ' ')
                             || '  '
                             || LPAD(ConvertCentsToDollars(r_transaction.CARDOLDVALUE), 10, ' ')
                             || '  '
                             || lPAD(ConvertCentsToDollars(r_transaction.TRANSACTIONAMOUNT), 7, ' ')
                             || '  '
                             || LPAD(ConvertCentsToDollars(r_transaction.CARDNEWVALUE), 10, ' ')
                             || '  '
                             || r_transaction.TRANSACTIONSEQ;
          WriteToFile(p_dir, p_file, v_output_string);
      END LOOP;
    END;

  FUNCTION FormatBSB(p_bsb VARCHAR2) RETURN VARCHAR2 IS
    /**
      Purpose: Formats a BSB for printing to the deskbank and daily banking summary
      Author: Alexander Price, 11995483
      Date: 25/05/2016
     */
    v_module_name VARCHAR2(35) := 'FormatBSB';
    BEGIN
      AnnounceMe(v_module_name);
      RETURN substr(p_bsb, 0, 3) || '-' || substr(p_bsb, 4, 3);
    END;

  PROCEDURE DailyBankingSummary(p_report_date VARCHAR2 DEFAULT to_char(sysdate, 'DD-MON-YYYY')) IS
    /**
      Purpose: Creates the daily banking summary file
      Author: Alexander Price, 11995483
      Date: 25/05/2016
     */
    v_module_name VARCHAR2(35) := 'DailyBankingSummary';
    v_directory_name VARCHAR2(35) := GetParameter('DIRECTORY', 'OUTPUT_DIRECTORY');
    v_deskbank_date VARCHAR2(8) := to_char(to_date(p_report_date), 'DDMMYYYY');
    v_file_name VARCHAR2(37) := 'DailyBankingSummary_' || v_deskbank_date || '_AWP.dat';
    v_debit_total NUMBER := 0;
    v_credit_total NUMBER := 0;
    v_output_string VARCHAR2(90);
    CURSOR c_settlement_records IS
      SELECT
        MERCHANTID,
        BSB,
        ACCOUNTNR,
        TRAN_CODE,
        SETTLEVALUE,
        substr(MERCHANTTITLE, 1, 29) AS MERCHANTTITLE
      FROM fss_daily_settlement
      WHERE to_char(CREATED, 'DD-MON-YYYY') = p_report_date;
    BEGIN
      AnnounceMe(v_module_name);
      ClearFile(v_directory_name, v_file_name);
      WriteToFile(v_directory_name, v_file_name, LPAD(' ', 30, ' ') || 'SMARTCARD SETTLEMENT SYSTEM');
      WriteToFile(v_directory_name, v_file_name, LPAD(' ', 33, ' ') || 'DAILY DESKBANK SUMMARY');
      WriteToFile(v_directory_name, v_file_name, 'Date ' || p_report_date);
      WriteToFile(v_directory_name, v_file_name, 'Merchant ID  Merchant Name                  Account Number     Debit         Credit');
      WriteToFile(v_directory_name, v_file_name, '-----------  -----------------------------  -----------------  ------------  ------------');
      FOR r_settlement_record IN c_settlement_records
        LOOP
          IF r_settlement_record.TRAN_CODE = 50 THEN
            v_credit_total := v_credit_total + r_settlement_record.SETTLEVALUE;
            v_output_string := RPAD(r_settlement_record.MERCHANTID, 11, ' ')
                               || '  '
                               || RPAD(r_settlement_record.MERCHANTTITLE, 29, ' ')
                               || '  '
                               || FormatBSB(r_settlement_record.BSB)
                               || RPAD(r_settlement_record.ACCOUNTNR, 10, ' ')
                               || '  '
                               || RPAD(' ', 14, ' ')
                               || LPAD(ConvertCentsToDollars(r_settlement_record.SETTLEVALUE), 12, ' ');
          ELSE
            v_debit_total := v_debit_total + r_settlement_record.SETTLEVALUE;
            v_output_string := RPAD(' ', 11, ' ')
                               || '  '
                               || RPAD(r_settlement_record.MERCHANTTITLE, 29, ' ')
                               || '  '
                               || FormatBSB(r_settlement_record.BSB)
                               || RPAD(r_settlement_record.ACCOUNTNR, 10, ' ')
                               || '  '
                               || LPAD(ConvertCentsToDollars(r_settlement_record.SETTLEVALUE), 12, ' ');
          END IF;
          WriteToFile(v_directory_name, v_file_name, v_output_string);
      END LOOP;
      WriteToFile(v_directory_name, v_file_name, RPAD(' ', 63, ' ') || '------------  ------------');
      WriteToFile(v_directory_name, v_file_name, 'BALANCE TOTAL'
                                                 || RPAD(' ', 50, ' ')
                                                 || LPAD(ConvertCentsToDollars(v_debit_total), 12, ' ')
                                                 || '  '
                                                 || LPAD(ConvertCentsToDollars(v_credit_total), 12, ' '));
      WriteToFile(v_directory_name, v_file_name, ' ');
      WriteToFile(v_directory_name, v_file_name, ' ');
      WriteToFile(v_directory_name, v_file_name, 'Deskbank file Name : DS_' || v_deskbank_date || '_AWP.dat');
      WriteToFile(v_directory_name, v_file_name, 'Dispatch Date      : ' || to_char(to_date(p_report_date), 'DD Mon YYYY'));
      WriteToFile(v_directory_name, v_file_name, LPAD(' ', 41, ' ') || '***** End of Report *****');
    END;

  FUNCTION GetMinimumSettlement RETURN NUMBER IS
    /**
      Purpose: Gets the minimum settlement amount. If it is the last day of the month,
                it will return 0 so that any left over transactions that were going
                to be less than the minimum settlement can be settled.
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'GetMinimumSettlement';
    BEGIN
      AnnounceMe(v_module_name);
      IF to_char(sysdate, 'DD/MON/YY') = to_char(LAST_DAY(sysdate), 'DD/MON/YY') THEN
        RETURN 0;
      ELSE
        RETURN ConvertDollarsToCents(GetReference('DMIN'));
      END IF;
    END;

  FUNCTION GetAmountToSettle(p_minimum_settlement NUMBER) RETURN NUMBER IS
    /**
      Purpose: Gets the amount of record merchants that need to be settled.
                Is used to determine whether or not to write out to the deskbank
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'GetAmountToSettle';
    v_amount NUMBER;
    BEGIN
      SELECT count(*) INTO v_amount FROM (
        SELECT
          sum(daily_transaction.transactionamount) total,
          merchant.merchantid merchantid
        FROM fss_merchant merchant
          JOIN fss_terminal terminal ON
            merchant.merchantid = terminal.merchantid
          JOIN fss_daily_transaction daily_transaction ON
            terminal.terminalid = daily_transaction.terminalid
        WHERE
          daily_transaction.transactionseq IS NULL
        GROUP BY
          merchant.merchantid
      ) WHERE total > p_minimum_settlement;
      RETURN v_amount;
    END;

  PROCEDURE CreateSettlementRecord(
    p_bsb VARCHAR2,
    p_accountnr VARCHAR2,
    p_transactioncode NUMBER,
    p_settlevalue NUMBER,
    p_merchantid NUMBER,
    p_merchanttitle VARCHAR2,
    p_bankflag VARCHAR2,
    p_lodgementnr VARCHAR2
  ) IS
    /**
      Procedure: Creates a settlement record
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'CreateSettlementRecord';
    BEGIN
      INSERT INTO fss_daily_settlement VALUES (
        1,
        p_bsb,
        p_accountnr,
        p_transactioncode,
        p_settlevalue,
        p_merchantid,
        p_merchanttitle,
        p_bankflag,
        p_lodgementnr,
        GetParameter('VARIABLE', 'TRACE'),
        GetParameter('VARIABLE', 'REMITTER'),
        GetParameter('VARIABLE', 'GST'),
        sysdate
      );
      COMMIT;
    END;


  PROCEDURE UpdateDailyTransactions(p_merchantid VARCHAR2, p_transaction_seq VARCHAR2) IS
    /**
      Purpose: Updates the daily transactions with the transaction seq
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'UpdateDailyTransactions';
    BEGIN
      AnnounceMe(v_module_name);
      UPDATE fss_daily_transaction
      SET fss_daily_transaction.transactionseq = p_transaction_seq
      WHERE fss_daily_transaction.transactionseq IS NULL AND
        fss_daily_transaction.terminalid IN (
          SELECT terminal.terminalid
          FROM fss_merchant merchant
            JOIN fss_terminal terminal ON
              merchant.merchantid = terminal.merchantid
            JOIN fss_daily_transaction daily_transaction ON
              terminal.terminalid = daily_transaction.terminalid
          WHERE merchant.merchantid = p_merchantid
          GROUP BY terminal.terminalid
      );
      COMMIT;
    END;

  FUNCTION CreateTransactionSequence RETURN VARCHAR2 IS
    /**
      Purpose: Generate a unique transaction sequence for the day
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'CreateTransactionSequence';
    BEGIN
      AnnounceMe(v_module_name);
      RETURN to_char(sysdate, 'YYYYMMDD') || LPAD(fss_daily_transaction_seq.nextval, 7, '0');
    END;

  FUNCTION GetTransactionsSettleCount RETURN NUMBER IS
    /**
      Purpose: Get the amount of transactions that need to be settled
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'GetTransactionsSettleCount';
    v_settle_count NUMBER;
    BEGIN
      AnnounceMe(v_module_name);
      RETURN v_settle_count;
    END;

  PROCEDURE SettleTransactions(p_file_name VARCHAR2) IS
    /**
      Purpose: Settle any transactions that have not been settled
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR(35) := 'SettleTransactions';
    v_minimum_settlement NUMBER := GetMinimumSettlement();
    CURSOR c_merchant_totals IS
      SELECT * FROM (
        SELECT
          substr(merchant.merchantlastname, 1, 32) accounttitle,
          sum(daily_transaction.transactionamount) total,
          merchant.merchantid merchantid,
          merchant.merchantbankbsb bsb,
          merchant.merchantbankaccnr accountnr
        FROM fss_merchant merchant
          JOIN fss_terminal terminal ON
            merchant.merchantid = terminal.merchantid
          JOIN fss_daily_transaction daily_transaction ON
            terminal.terminalid = daily_transaction.terminalid
        WHERE
          daily_transaction.transactionseq IS NULL
        GROUP BY
          merchant.merchantid,
          merchant.merchantbankbsb,
          merchant.merchantbankaccnr,
          merchant.merchantlastname
      )
    WHERE total > v_minimum_settlement;
    v_transaction_seq VARCHAR2(15);
    v_record_count NUMBER := GetAmountToSettle(v_minimum_settlement);
    v_credit_total NUMBER := 0;
    v_debit_total NUMBER := 0;
    v_organisation_bsb VARCHAR2(6);
    v_organisation_accountnr VARCHAR2(9);
    v_organisation_accounttitle VARCHAR2(32);
    v_organisation_id VARCHAR2(6) := GetParameter('VARIABLE', 'ORGID');
    BEGIN
      AnnounceMe(v_module_name);
      IF v_record_count > 0 THEN
        SELECT
          orgbsbnr,
          orgbankaccount,
          substr(orgaccounttitle, 1, 32)
        INTO
          v_organisation_bsb,
          v_organisation_accountnr,
          v_organisation_accounttitle
        FROM fss_organisation
        WHERE orgnr = v_organisation_id;
        WriteDeskbankHeader(p_file_name, v_organisation_accounttitle, v_organisation_bsb);
        FOR r_merchant_total IN c_merchant_totals
          LOOP
            v_transaction_seq := CreateTransactionSequence();
            v_credit_total := v_credit_total + r_merchant_total.total;
            v_debit_total := v_debit_total + r_merchant_total.total;
            UpdateDailyTransactions(r_merchant_total.merchantid, v_transaction_seq);
            CreateSettlementRecord(
              r_merchant_total.bsb,
              r_merchant_total.accountnr,
              50,
              r_merchant_total.total,
              r_merchant_total.merchantid,
              r_merchant_total.accounttitle,
              ' F ',
              v_transaction_seq
            );
            WriteDeskbankRecord(
              p_file_name,
              r_merchant_total.bsb,
              r_merchant_total.accountnr,
              50,
              r_merchant_total.total,
              r_merchant_total.accounttitle,
              ' F ',
              v_transaction_seq
            );
        END LOOP;
        WriteOrganisationRecord(
          p_file_name,
          v_debit_total,
          v_organisation_bsb,
          v_organisation_accountnr,
          v_organisation_accounttitle,
          v_organisation_id
        );
        v_record_count := v_record_count + 1;
        WriteDeskbankFooter(p_file_name, v_credit_total - v_debit_total, v_credit_total, v_debit_total, v_record_count);
      END IF;
    END;

  PROCEDURE WriteOrganisationRecord(p_file_name VARCHAR2,
    p_debit_total NUMBER,
    p_organisation_bsb VARCHAR2,
    p_organisation_accountnr VARCHAR2,
    p_organisation_accounttitle VARCHAR2,
    p_organisation_id VARCHAR2
  ) IS
    /**
      Purpose: Write out the organisation debit record to both the deskbank file
                and the to the settlement table
      Author: Alexander Price, 11995483
      Date: 25/05/2016
     */
    v_module_name VARCHAR2(35) := 'WriteOrganisationRecord';
    v_transaction_seq VARCHAR2(15) := CreateTransactionSequence();
    BEGIN
      AnnounceMe(v_module_name);
      CreateSettlementRecord(
        p_organisation_bsb,
        p_organisation_accountnr,
        13,
        p_debit_total,
        p_organisation_id,
        p_organisation_accounttitle,
        ' N ',
        v_transaction_seq
      );
      WriteDeskbankRecord(
        p_file_name,
        p_organisation_bsb,
        p_organisation_accountnr,
        13,
        p_debit_total,
        p_organisation_accounttitle,
        ' N ',
        v_transaction_seq
      );
    END;

  FUNCTION CheckRunTable(p_runid NUMBER) RETURN BOOLEAN IS
    /**
      Purpose: Check if the daily run has been run today
      Author: Alexander Price, 11995483
      Date: 19/05/2016
     */
    v_module_name VARCHAR(35) := 'CheckRunTable';
    v_run_result NUMBER;
    BEGIN
      AnnounceMe(v_module_name);
      SELECT count(*) INTO v_run_result FROM fss_run_table WHERE
      to_char(runstart, 'YYYY-MM-DD') = to_char(sysdate, 'YYYY-MM-DD') AND runid != p_runid;
      RETURN v_run_result <= 0;
    END;

  PROCEDURE AnnounceMe(p_module_name VARCHAR2, p_destination VARCHAR2 DEFAULT 'T') IS
    /**
      Purpose: A procedure for announcing that a module is being run. If specified,
                it will output to the server output, otherwise it will go to the
                DBP_MESSAGE_LOG table
     */
    v_message VARCHAR2(255) := 'In module ' || p_module_name;
    BEGIN
      IF p_destination = 'T' THEN
        common.log(v_message);
      ELSE
        DBMS_OUTPUT.put_line(v_message);
      END IF;
    END;

  PROCEDURE UploadNewTransactions IS
    /**
      Purpose: Get the latest transactions from the fss_transactions table
                and update our table (fss_daily_transaction) with the
                latest transactions
      Author: Alexander Price, 11995483
      Date: 19/05/2016
    */
    v_module_name VARCHAR2(35) := 'UploadNewTransactions';
    BEGIN
      AnnounceMe(v_module_name);
      INSERT INTO fss_daily_transaction (
        TRANSACTIONNR,
        DOWNLOADDATE,
        TERMINALID,
        CARDID,
        TRANSACTIONDATE,
        CARDOLDVALUE,
        TRANSACTIONAMOUNT,
        CARDNEWVALUE,
        TRANSACTIONSTATUS,
        ERRORCODE
      ) SELECT t1.TRANSACTIONNR,
               t1.DOWNLOADDATE,
               t1.TERMINALID,
               t1.CARDID,
               t1.TRANSACTIONDATE,
               t1.CARDOLDVALUE,
               t1.TRANSACTIONAMOUNT,
               t1.CARDNEWVALUE,
               t1.TRANSACTIONSTATUS,
               t1.ERRORCODE
      FROM fss_transactions t1 WHERE NOT exists(
          SELECT 1 FROM fss_daily_transaction t2 where t1.transactionnr = t2.transactionnr
      );
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
      common.log('Exception thrown in ' || v_module_name || ' with error ' || sqlcode);
    END;

  FUNCTION CreateRunTableEntry RETURN NUMBER IS
    /**
      Purpose: Create a run table entry for the run. It will by default set the
                outcome of the run to failure. When the run successfully finishes,
                it will be updated to success.
      Author: Alexander Price, 11995483
      Date: 19/05/2016
    */
    v_module_name VARCHAR2(35) := 'CreateRunTableEntry';
    v_runid NUMBER := fss_run_table_seq.nextval;
    BEGIN
      AnnounceMe(v_module_name);
      INSERT INTO fss_run_table(
        runid,
        runstart,
        runend,
        runoutcome,
        remarks
      ) VALUES (
        v_runid,
        sysdate,
        sysdate,
        'FAILURE',
        'Initial run entry creation'
      );
      COMMIT;
      RETURN v_runid;
    END;

  PROCEDURE UpdateRunTableEntry(p_runid NUMBER, p_runoutcome VARCHAR2, p_remarks VARCHAR2 DEFAULT 'N/A') IS
    /**
      Purpose: Updates a run table entry
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'UpdateRunTableEntry';
    BEGIN
      AnnounceMe(v_module_name);
      UPDATE fss_run_table SET
        fss_run_table.runoutcome = p_runoutcome,
        fss_run_table.remarks = p_remarks,
        fss_run_table.runend = sysdate
      WHERE fss_run_table.runid = p_runid;
      COMMIT;
    END;

  PROCEDURE DailySettlement IS
    /**
      Purpose: Complete the daily settlement (Check run table, upload new transactions
                and settle transactions)
      Author: Alexander Price, 11995483
      Date: 19/05/2016
     */
    v_module_name VARCHAR2(35) := 'DailySettlement';
    v_runid NUMBER;
    v_deskbank_date VARCHAR2(8) := to_char(sysdate, 'DDMMYYYY');
    v_deskbank_file_name VARCHAR2(19) := 'DS_' || v_deskbank_date || '_AWP.dat';
    BEGIN
      AnnounceMe(v_module_name);
      -- Create our run table entry
      v_runid := CreateRunTableEntry();
      -- First thing, check if the run has been done today (ignoring the entry we just made)
      IF NOT CheckRunTable(v_runid) THEN
        UpdateRunTableEntry(v_runid, 'FAILURE', 'Run has already been run today');
      ELSE
        UploadNewTransactions();
        SettleTransactions(v_deskbank_file_name);
        DailyBankingSummary();
        UpdateRunTableEntry(v_runid, 'SUCCESS', 'Run completed successfully');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        UpdateRunTableEntry(v_runid, 'FAILURE', 'ERROR ENCOUNTERED: ' || SQLCODE || ': ' || SQLERRM);
    END;

  PROCEDURE WriteDeskbankHeader(
    p_file_name VARCHAR2,
    p_organisation_accounttitle VARCHAR2,
    p_organisation_bsb VARCHAR2
  ) IS
    /**
      Purpose: Creates the deskbank header and writes it to the specified file
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'WriteDeskbankHeader';
    v_output_string VARCHAR2(120);
    BEGIN
      AnnounceMe(v_module_name);
      v_output_string := '0'
                         || RPAD(' ', 17, ' ')
                         || GetParameter('VARIABLE', 'REELSEQUENCE')
                         || GetParameter('VARIABLE', 'FICODE')
                         || RPAD(' ', 7, ' ')
                         || RPAD(p_organisation_accounttitle, 26, ' ')
                         || p_organisation_bsb
                         || RPAD(GetParameter('VARIABLE', 'HEADERDESCRIPTION'), 12, ' ')
                         || to_char(sysdate, 'DDMMYY')
                         || RPAD(' ', 40, ' ');
      WriteToFile(GetParameter('DIRECTORY', 'OUTPUT_DIRECTORY'), p_file_name, v_output_string);
    END;

  PROCEDURE WriteDeskbankFooter(
    p_file_name VARCHAR2,
    p_file_total NUMBER,
    p_credit_total NUMBER,
    p_debit_total NUMBER,
    p_record_count NUMBER
  ) IS
    /**
      Purpose: Creates the deskbank footer and writes it to the specified file
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'WriteDeskbankFooter';
    v_output_string VARCHAR2(120);
    BEGIN
      AnnounceMe(v_module_name);
      v_output_string := '7'
                         || GetParameter('VARIABLE', 'FILLER')
                         || RPAD(' ', 12, ' ')
                         || LPAD(p_file_total, 10, '0')
                         || LPAD(p_credit_total, 10, '0')
                         || LPAD(p_debit_total, 10, '0')
                         || RPAD(' ', 24, ' ')
                         || LPAD(p_record_count, 6, '0')
                         || RPAD(' ', 40, ' ');
      WriteToFile(GetParameter('DIRECTORY', 'OUTPUT_DIRECTORY'), p_file_name, v_output_string);
    END;

  PROCEDURE WriteDeskbankRecord(
    p_file_name VARCHAR2,
    p_bsb VARCHAR2,
    p_accountnr VARCHAR2,
    p_transactioncode NUMBER,
    p_value NUMBER,
    p_merchanttitle VARCHAR2,
    p_bankflag VARCHAR2,
    p_lodgementnr VARCHAR2
  ) IS
    /**
      Purpose: Creates a Deskbank record from the parameters and then writes
                it to the specified file
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'WriteDeskbankFooter';
    v_output_string VARCHAR2(120);
    BEGIN
      AnnounceMe(v_module_name);
      v_output_string := '1'
                         || FormatBSB(p_bsb)
                         || lpad(p_accountnr, 9, '0')
                         || ' '
                         || p_transactioncode
                         || lpad(p_value, 10, '0')
                         || UPPER(rpad(p_merchanttitle, 32, ' '))
                         || p_bankflag
                         || p_lodgementnr
                         || GetParameter('VARIABLE', 'TRACE')
                         || GetParameter('VARIABLE', 'REMITTER')
                         || GetParameter('VARIABLE', 'GST');
      WriteToFile(GetParameter('DIRECTORY', 'OUTPUT_DIRECTORY'), p_file_name, v_output_string);
    END;

  PROCEDURE WriteToFile(p_directory VARCHAR2, p_file_name VARCHAR2, p_line VARCHAR2) IS
    /**
      Purpose: Writes a line to the specified filed
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'WriteToFile';
    v_file utl_file.file_type;
    BEGIN
      AnnounceMe(v_module_name);
      v_file := utl_file.fopen(p_directory, p_file_name, 'A');
      utl_file.put_line(v_file, p_line);
      utl_file.fclose(v_file);
    END;

  FUNCTION DateToTimestamp(p_date DATE DEFAULT sysdate) RETURN NUMBER IS
    /**
      Purpose: Converts a date to a unix timestamp
      Author: Alexander Price
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'DateToTimestamp';
    v_timestamp number;
    BEGIN
      AnnounceMe(v_module_name);
      v_timestamp := (p_date - DATE '1970-01-01') * 60 * 60 * 24;
      RETURN v_timestamp;
    END;

  FUNCTION GetParameter(p_kind VARCHAR2, p_code VARCHAR2) RETURN VARCHAR2 IS
    /**
      Purpose: Gets the specified parameter from the parameter table
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'GetParameter';
    v_result VARCHAR2(255);
    BEGIN
      SELECT value INTO v_result
      FROM parameter
      WHERE
        kind = p_kind AND
        code = p_code AND
        active = 'Y';
      RETURN v_result;
    END;

  FUNCTION GetReference(p_id VARCHAR2) RETURN VARCHAR2 IS
    /**
      Purpose: Gets the specified reference from the fss_reference table
      Author: Alexander Price, 11995483
      Date: 21/05/2016
     */
    v_module_name VARCHAR2(35) := 'GetReference';
    v_result VARCHAR2(255);
    BEGIN
      SELECT referencevalue INTO v_result
      FROM fss_reference
      WHERE
        referenceid = p_id;
      RETURN v_result;
    END;

  FUNCTION ConvertDollarsToCents(p_dollars FLOAT) RETURN NUMBER IS
    /**
      Purpose: Converts the specified dollar amount to cents
      Author: Alexander Price, 11995483
      Date: 24/05/2016
     */
    v_module_name VARCHAR2(35) := 'ConvertDollarsToCents';
    BEGIN
      RETURN p_dollars * 100;
    END;

  FUNCTION ConvertCentsToDollars(p_cents NUMBER) RETURN VARCHAR2 IS
    /**
      Purpose: Converts the specified cent amount to dollars
      Author: Alexander Price, 11995483
      Date: 25/05/2016
     */
    v_module_name VARCHAR2(35) := 'ConvertCentsToDollars';
    v_formatted VARCHAR2(10) := ltrim(to_char(p_cents / 100, '999999999.99'));
    BEGIN
      IF p_cents < 1 THEN
        RETURN '00' || v_formatted;
      ELSE
        RETURN v_formatted;
      END IF;
    END;

  PROCEDURE ClearFile(p_directory VARCHAR2, p_file VARCHAR2) IS
    /**
      Purpose: Clears a file
      Author: Alexander Price, 11995483
      Date: 26/05/2016
     */
    v_module_name VARCHAR2(35) := 'ClearFile';
    v_file utl_file.file_type;
    BEGIN
      AnnounceMe(v_module_name);
      v_file := utl_file.fopen(p_directory, p_file, 'W');
      utl_file.put_line(v_file, '');
      utl_file.fclose(v_file);
    END;

END Pkg_FSS_Settlement;