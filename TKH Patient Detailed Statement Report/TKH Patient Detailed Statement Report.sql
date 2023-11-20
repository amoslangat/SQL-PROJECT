SELECT
 *
FROM (
   select
       c.party_name
     , c.customer_number
     , c.invoice_number
     , c.transaction_date
     , c.gl_date
     , c.transaction_currency
     , c.Transaction_Type
     , c.transaction_original_amount
     , c.functional_currency
     , c.transaction_applied_amount
     , c.functional_original_amount
     , c.transaction_remaining_amount
     , c.functional_remaining_amount
     , c.exchange_rate
     , c.patient_id
     , c.patient_name
     , c.plan_name
from
       (
                select
                         b.party_name
                       , b.customer_number
                       , b.invoice_number
                       , to_char(b.transaction_date,'YYYY-MM-DD') transaction_date
                       , to_char(b.gl_date,'YYYY-MM-DD')          gl_date
                       , b.currency                               transaction_currency
                       , b.Transaction_Type
                       , sum(b.transaction_original_amount) transaction_original_amount
                       , b.functional_currency
                       , b.applied_amount                                                transaction_applied_amount
                       , sum(b.functional_original_amount)                               functional_original_amount
                       , b.functional_applied_amount                                     transaction_remaining_amount -- transaction_applied_amount
                       , sum(b.functional_original_amount) - b.functional_applied_amount functional_remaining_amount  -- transaction_receipt_remaining_amount
                       , b.exchange_rate
                       , b.patient_id
                       , b.patient_name
                       , b.plan_name
                from
                         (
                                select
                                       hp.party_name
                                     , hca.account_number customer_number
                                     , rcta.trx_number    invoice_number
                                     , rcta.trx_date      transaction_date
                                     , rctlg.gl_date
                                     , rcta.INVOICE_CURRENCY_CODE    currency
                                     ,'INV'                          Transaction_type
                                     , rctla.extended_amount         transaction_Original_Amount
                                     ,'KES'                          Functional_Currency
                                     , nvl(a.total_applied_amount,0) applied_amount
                                     , CASE
                                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                                     THEN null
                                                     ELSE
                                                          (
                                                                 select
                                                                        conversion_rate
                                                                 from
                                                                        gl_daily_rates
                                                                 where
                                                                        to_currency         = 'KES'
                                                                        and from_currency   = rcta.invoice_currency_code
                                                                        and conversion_Date = trunc(rcta.trx_date)
                                                     )
                                       END EXCHANGE_RATE
                                     , CASE
                                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                                     THEN nvl(a.total_applied_amount,0)
                                                     ELSE a.total_applied_amount *
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = rcta.invoice_currency_code
                                                                   and conversion_Date = trunc(rcta.trx_date)
                                                     )
                                       END functional_applied_amount
                                     , CASE
                                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                                     THEN rctla.extended_amount
                                                     ELSE rctla.extended_amount*
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = rcta.invoice_currency_code
                                                                   and conversion_Date = trunc(rcta.trx_date)
                                                     )
                                       END Functional_Original_Amount
                                     , CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                     else null
                                       end Patient_Id
                                     , CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute2
                                                     else null
                                       end Patient_Name
                                     , CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute12
                                                     else null
                                       end Plan_Name
                                from
                                       ra_customer_trx_all          rcta
                                     , ra_customer_trx_lines_all    rctla
                                     , ra_cust_trx_line_gl_dist_all rctlg
                                     , hz_parties                   hp
                                     , hz_cust_accounts             hca
                                     , (
                                                select
                                                         hp1.party_name
                                                       , rcta1.bill_to_customer_id
                                                     --  , araa1.cash_receipt_id
                                                       , rcta1.customer_trx_id
													   , hca1.account_number
                                                       , sum(araa1.amount_applied) total_applied_amount
                                                from
                                                         ar_receivable_applications_all araa1
                                                       , ar_cash_receipts_all           acra1
                                                       , ra_customer_trx_all            rcta1
                                                       , hz_cust_accounts               hca1
                                                       , hz_parties                     hp1
                                                where
                                                         araa1.cash_receipt_id            = acra1.cash_receipt_id
                                                         and araa1.status                 = 'APP'
                                                         and ARAA1.CASH_RECEIPT_ID        =ACRA1.CASH_RECEIPT_ID
                                                         AND ARAA1.APPLIED_CUSTOMER_TRX_ID=RCTA1.CUSTOMER_TRX_ID
                                                         and rcta1.bill_to_customer_id    = hca1.cust_account_id
                                                         and hca1.party_id                = hp1.party_id
                                                         --and hca1.account_number = nvl(:p_party_name, hca1.account_number)
														 --and hca1.account_number = hca.account_number
                                                    --  and trunc(rcta1.trx_date) between :p_from_date and :p_to_date
                                                         -- and trunc(acra1.receipt_date) between :p_from_date and :p_to_date
                                                group by
                                                         rcta1.bill_to_customer_id
                                                      --- , araa1.cash_receipt_id
                                                       , hp1.party_name
                                                       , rcta1.customer_trx_id
													   , hca1.account_number
                                       )
                                       a
                                where
                                       1                              =1
                                       and rcta.bill_to_customer_id   = hca.cust_account_id
                                       and rcta.customer_trx_id       = rctla.customer_trx_id
                                       and rctla.line_type            = 'LINE'
                                       and rctla.customer_trx_line_id = rctlg.customer_trx_line_id
                                       and hp.party_id                = hca.party_id
                                       --and hp.party_name = 'TEST1'
                                       --and hp.party_name = nvl(:p_party_name,hp.party_name)
									   AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                     else 'ZZZ'
                                       end ) = :p_party_id
									   /*AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute2
                                                     else null
                                            end) = :p_party_name*/
                                       --and hca.account_number = nvl(:p_party_name, hca.account_number)
                                    --and trunc(rcta.trx_date) between :p_from_date and :p_to_date
                                       --and rcta.trx_number in ('Test001','REP001')
									   AND hca.account_number = a.account_number(+)
                                       and rcta.customer_trx_id     = a.customer_trx_id(+) -- added v2
                                       and rcta.bill_to_customer_id = a.bill_to_customer_id(+)
                                       and hp.party_name            = a.party_name(+)
                         )
                         b
                         where   b.transaction_date BETWEEN :p_from_date AND :p_to_date
                group by
                         b.party_name
                       , b.customer_number
                       , b.invoice_number
                       , b.transaction_date
                       , b.gl_date
                       , b.currency
                       , b.transaction_type
                       , b.functional_currency
                       , b.exchange_rate
                       , b.patient_id
                       , b.patient_name
                       , b.plan_name
                       , b.applied_amount
                       , b.functional_applied_amount
       )
       c

union  ALL
select
         a.party_name
       , a.customer_number
       , a.receipt_number
       , to_char(a.receipt_date,'YYYY-MM-DD') receipt_date
       , max(to_char(a.gl_date,'YYYY-MM-DD')) gl_date
       , a.currency                           transaction_currency
       , a.transaction_type
       ,(-1)*a.transaction_amount transaction_original_amount
       , a.functional_currency
       , sum(a.transaction_applied_amount)                                    transaction_applied_amount
       ,(-1)*a.Functional_Original_Amount                                     functional_original_amount
       ,(-1)* sum(a.functional_applied_amount)                                transaction_remaining_amount -- transaction_applied_amount
       ,(-1)*(a.Functional_Original_Amount- sum(a.functional_applied_amount)) Functional_Remianing_amount  -- transaction_receipt_remaining_amount
       , a.exchange_rate
       , a.patient_id
       , a.patient_name
       , a.plan_name
from
         (
                select
                       hp.party_name
                     , hca.account_number customer_number
                     , acra.RECEIPT_NUMBER
                     , acra.receipt_date  receipt_date
                     , araa.gl_date       gl_date
                     , acra.currency_code currency
                     , acra.amount        Transaction_Amount
                     ,'KES'               Functional_Currency
                     , CASE
                              WHEN acra.currency_code = 'KES'
                                     THEN null
                                     ELSE
                                          (
                                                 select
                                                        conversion_rate
                                                 from
                                                        gl_daily_rates
                                                 where
                                                        to_currency         = 'KES'
                                                        and from_currency   = acra.currency_code
                                                        and conversion_Date = trunc(acra.receipt_date)
                                     )
                       END EXCHANGE_RATE
                     , CASE
                              WHEN substr(acra.receipt_number,1,2) = 'DR'
                                     THEN 'DEP'
                                     ELSE 'RCPT'
                       END                 Transaction_type
                     , araa.amount_applied transaction_applied_amount
                     , CASE
                              WHEN acra.currency_code = 'KES'
                                     THEN araa.amount_applied
                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                     and acra.currency_code  <> 'KES'
                                     THEN araa.amount_applied
                              WHEN rcta.INVOICE_CURRENCY_CODE <> 'KES'
                                     and acra.currency_code   <> 'KES'
                                     THEN araa.amount_applied*
                                     (
                                            select
                                                   conversion_rate
                                            from
                                                   gl_daily_rates
                                            where
                                                   to_currency         = 'KES'
                                                   and from_currency   = acra.currency_code
                                                   and conversion_Date = trunc(acra.receipt_date)
                                     )
                       END Functional_applied_Amount
                     , CASE
                              WHEN acra.currency_code = 'KES'
                                     THEN acra.amount
                                     ELSE acra.amount*
                                     (
                                            select
                                                   conversion_rate
                                            from
                                                   gl_daily_rates
                                            where
                                                   to_currency         = 'KES'
                                                   and from_currency   = acra.currency_code
                                                   and conversion_Date = trunc(acra.receipt_date)
                                     )
                       END             Functional_Original_Amount
                     , acra.attribute1 PATIENT_ID
                     , null            Patient_name
                     , null            Plan_Name
                from
                       AR_CASH_RECEIPTS_ALL           acra
                     , ar_receivable_applications_all araa
                     , ra_customer_trx_all            rcta
                     , hz_cust_accounts               hca
                     , hz_parties                     hp
                where
                       1=1
                       --and rcta.bill_to_customer_id = hca.cust_account_id
                       and ACRA.PAY_FROM_CUSTOMER = HCA.CUST_ACCOUNT_ID(+)
                       and hp.party_id            = hca.party_id
                       --and hp.party_name = 'TEST1'
                       AND ARAA.APPLIED_CUSTOMER_TRX_ID=RCTA.CUSTOMER_TRX_ID
                       and acra.cash_receipt_id        = araa.cash_receipt_id
                       and araa.status                 = 'APP'
                       and acra.status                <> 'REV'
                       --and hp.party_name = nvl(:p_party_name,hp.party_name)
                       --and hca.account_number = nvl(:p_party_name, hca.account_number)
					   AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                 
                                       end ) = :p_party_id					   
                   ---    and trunc(rcta.trx_date) between :p_from_date and :p_to_date
                       --and acra.receipt_number = 'DR103448'
         )
         a
         
         where    a.Functional_Original_Amount <>0
group by
         a.party_name
       , a.customer_number
       , a.receipt_number
       , a.receipt_date
       , a.currency
       , a.transaction_type
       , a.transaction_amount
       , a.functional_currency
       , a.Functional_Original_Amount
       , a.exchange_rate
       , a.patient_id
       , a.patient_name
       , a.plan_name
union
select
       y.party_name
     , y.customer_number
     , y.receipt_number
     , y.receipt_date
     , y.gl_date
     , y.transaction_currency
     , y.transaction_type
     , y.transaction_original_amount
     , y.functional_currency
     , y.transaction_applied_amount
     , y.functional_original_amount
     , y.transaction_remaining_amount -- transaction_applied_amount
     , y.Functional_Remianing_amount  -- transaction_receipt_remaining_amount
     , y.exchange_rate
     , y.patient_id
     , y.patient_name
     , y.plan_name
from
       (
                select
                         a.party_name
                       , a.customer_number
                       , a.receipt_number
                       , to_char(a.receipt_date,'YYYY-MM-DD') receipt_date
                       , max(to_char(a.gl_date,'YYYY-MM-DD')) gl_date
                       , a.currency                           transaction_currency
                       , a.transaction_type
                       ,(-1)*a.transaction_amount transaction_original_amount
                       , a.functional_currency
                       , sum(a.transaction_applied_amount)                                           transaction_applied_amount
                       ,(-1)*a.Functional_Original_Amount                                            functional_original_amount
                       ,(-1)* sum(nvl(a.functional_applied_amount,0))                                transaction_remaining_amount -- transaction_applied_amount
                       ,(-1)*(a.Functional_Original_Amount- sum(nvl(a.functional_applied_amount,0))) Functional_Remianing_amount  -- transaction_receipt_remaining_amount
                       , a.exchange_rate
                       , a.patient_id
                       , a.patient_name
                       , a.plan_name
                from
                         (
                                select
                                       hp.party_name
                                     , hca.account_number customer_number
                                     , acra.RECEIPT_NUMBER
                                     , acra.receipt_date  receipt_date
                                     , araa.gl_date       gl_date
                                     , acra.currency_code currency
                                     , acra.amount        Transaction_Amount
                                     ,'KES'               Functional_Currency
                                     , CASE
                                              WHEN acra.currency_code = 'KES'
                                                     THEN null
                                                     ELSE
                                                          (
                                                                 select
                                                                        conversion_rate
                                                                 from
                                                                        gl_daily_rates
                                                                 where
                                                                        to_currency         = 'KES'
                                                                        and from_currency   = acra.currency_code
                                                                        and conversion_Date = trunc(acra.receipt_date)
                                                                        and rownum          =1
                                                     )
                                       END EXCHANGE_RATE
                                     , CASE
                                              WHEN substr(acra.receipt_number,1,2) = 'DR'
                                                     THEN 'DEP'
                                                     ELSE 'RCPT'
                                       END                 Transaction_type
                                     , araa.amount_applied transaction_applied_amount
                                     , CASE
                                              WHEN acra.currency_code = 'KES'
                                                     THEN
                                                     (
                                                              select
                                                                       sum(x.amount_applied)
                                                              from
                                                                       ar_receivable_applications_all x
                                                              where
                                                                       x.cash_receipt_id = acra.cash_receipt_id
                                                                       and x.status      = 'APP'
                                                              group by
                                                                       x.cash_receipt_id
                                                     )
                                                     --araa.amount_applied
                                                     ELSE
                                                          (
                                                                   select
                                                                            sum(x.amount_applied)
                                                                   from
                                                                            ar_receivable_applications_all x
                                                                   where
                                                                            x.cash_receipt_id = acra.cash_receipt_id
                                                                            and x.status      = 'APP'
                                                                   group by
                                                                            x.cash_receipt_id
                                                     )
                                                     *
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = acra.currency_code
                                                                   and conversion_Date = trunc(acra.receipt_date)
                                                                   and rownum          =1
                                                     )
                                       END Functional_applied_Amount
                                     , CASE
                                              WHEN acra.currency_code = 'KES'
                                                     THEN acra.amount
                                                     ELSE acra.amount*
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = acra.currency_code
                                                                   and conversion_Date = trunc(acra.receipt_date)
                                                                   and rownum          =1
                                                     )
                                       END             Functional_Original_Amount
                                     , acra.attribute1 PATIENT_ID
                                     , null            Patient_name
                                     , null            Plan_Name
                                from
                                       AR_CASH_RECEIPTS_ALL           acra
                                     , ar_receivable_applications_all araa
                                     , ra_customer_trx_all            rcta
                                     , hz_cust_accounts               hca
                                     , hz_parties                     hp
                                where
                                       1=1
                                       --and rcta.bill_to_customer_id = hca.cust_account_id
                                       and ACRA.PAY_FROM_CUSTOMER = HCA.CUST_ACCOUNT_ID(+)
                                       and acra.status           <> 'REV'
                                       and hp.party_id            = hca.party_id
                                       --and hp.party_name = 'TEST1'
                                       AND ARAA.APPLIED_CUSTOMER_TRX_ID=RCTA.CUSTOMER_TRX_ID(+)
                                       and acra.cash_receipt_id        = araa.cash_receipt_id
                                       and araa.status                 = 'UNAPP'
                                       --and hp.party_name = nvl(:p_party_name,hp.party_name)
                                       --and hca.account_number = nvl(:p_party_name, hca.account_number)
									   AND acra.attribute1  = :p_party_id
                                       and trunc(acra.receipt_date) between :p_from_date and :p_to_date
                                       --and acra.receipt_number = 'DR103448'
                         )
                         a
                group by
                         a.party_name
                       , a.customer_number
                       , a.receipt_number
                       , a.receipt_date
                       , a.currency
                       , a.transaction_type
                       , a.transaction_amount
                       , a.functional_currency
                       , a.Functional_Original_Amount
                       , a.exchange_rate
                       , a.patient_id
                       , a.patient_name
                       , a.plan_name
       )
       y
where
       y.Functional_Original_Amount = y.Functional_Remianing_amount
) 
WHERE PARTY_NAME = 'TKH CASHIER'
ORDER BY TO_DATE(transaction_date, 'YYYY-MM-DD') ASC



G2

select  *  from (
     select
       c.party_name
     , c.customer_number
     , c.invoice_number
     , c.transaction_date
     , c.gl_date
     , c.transaction_currency
     , c.Transaction_Type
     , c.transaction_original_amount
     , c.functional_currency
     , c.transaction_applied_amount
     , c.functional_original_amount
     , c.transaction_remaining_amount
     , c.functional_remaining_amount
     , c.exchange_rate
     , c.patient_id
     , c.patient_name
     , c.plan_name
from
       (
                select
                         b.party_name
                       , b.customer_number
                       , b.invoice_number
                       , to_char(b.transaction_date,'DD-MM-YYYY') transaction_date
                       , to_char(b.gl_date,'DD-MM-YYYY')          gl_date
                       , b.currency                               transaction_currency
                       , b.Transaction_Type
                       , sum(b.transaction_original_amount) transaction_original_amount
                       , b.functional_currency
                       , b.applied_amount                                                transaction_applied_amount
                       , sum(b.functional_original_amount)                               functional_original_amount
                       , b.functional_applied_amount                                     transaction_remaining_amount -- transaction_applied_amount
                       , sum(b.functional_original_amount) - b.functional_applied_amount functional_remaining_amount  -- transaction_receipt_remaining_amount
                       , b.exchange_rate
                       , b.patient_id
                       , b.patient_name
                       , b.plan_name
                from
                         (
                                select
                                       hp.party_name
                                     , hca.account_number customer_number
                                     , rcta.trx_number    invoice_number
                                     , rcta.trx_date      transaction_date
                                     , rctlg.gl_date
                                     , rcta.INVOICE_CURRENCY_CODE    currency
                                     ,'INV'                          Transaction_type
                                     , rctla.extended_amount         transaction_Original_Amount
                                     ,'KES'                          Functional_Currency
                                     , nvl(a.total_applied_amount,0) applied_amount
                                     , CASE
                                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                                     THEN null
                                                     ELSE
                                                          (
                                                                 select
                                                                        conversion_rate
                                                                 from
                                                                        gl_daily_rates
                                                                 where
                                                                        to_currency         = 'KES'
                                                                        and from_currency   = rcta.invoice_currency_code
                                                                        and conversion_Date = trunc(rcta.trx_date)
                                                     )
                                       END EXCHANGE_RATE
                                     , CASE
                                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                                     THEN nvl(a.total_applied_amount,0)
                                                     ELSE a.total_applied_amount *
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = rcta.invoice_currency_code
                                                                   and conversion_Date = trunc(rcta.trx_date)
                                                     )
                                       END functional_applied_amount
                                     , CASE
                                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                                     THEN rctla.extended_amount
                                                     ELSE rctla.extended_amount*
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = rcta.invoice_currency_code
                                                                   and conversion_Date = trunc(rcta.trx_date)
                                                     )
                                       END Functional_Original_Amount
                                     , CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                     else null
                                       end Patient_Id
                                     , CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute2
                                                     else null
                                       end Patient_Name
                                     , CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute12
                                                     else null
                                       end Plan_Name
                                from
                                       ra_customer_trx_all          rcta
                                     , ra_customer_trx_lines_all    rctla
                                     , ra_cust_trx_line_gl_dist_all rctlg
                                     , hz_parties                   hp
                                     , hz_cust_accounts             hca
                                     , (
                                                select
                                                         hp1.party_name
                                                       , rcta1.bill_to_customer_id
                                                     --  , araa1.cash_receipt_id
                                                       , rcta1.customer_trx_id
													   , hca1.account_number
                                                       , sum(araa1.amount_applied) total_applied_amount
                                                from
                                                         ar_receivable_applications_all araa1
                                                       , ar_cash_receipts_all           acra1
                                                       , ra_customer_trx_all            rcta1
                                                       , hz_cust_accounts               hca1
                                                       , hz_parties                     hp1
                                                where
                                                         araa1.cash_receipt_id            = acra1.cash_receipt_id
                                                         and araa1.status                 = 'APP'
                                                         and ARAA1.CASH_RECEIPT_ID        =ACRA1.CASH_RECEIPT_ID
                                                         AND ARAA1.APPLIED_CUSTOMER_TRX_ID=RCTA1.CUSTOMER_TRX_ID
                                                         and rcta1.bill_to_customer_id    = hca1.cust_account_id
                                                         and hca1.party_id                = hp1.party_id
                                                         --and hca1.account_number = nvl(:p_party_name, hca1.account_number)
														 --and hca1.account_number = hca.account_number
                                                         and trunc(rcta1.trx_date) between :p_from_date and :p_to_date
                                                group by
                                                         rcta1.bill_to_customer_id
                                                      --- , araa1.cash_receipt_id
                                                       , hp1.party_name
                                                       , rcta1.customer_trx_id
													   , hca1.account_number
                                       )
                                       a
                                where
                                       1                              =1
                                       and rcta.bill_to_customer_id   = hca.cust_account_id
                                       and rcta.customer_trx_id       = rctla.customer_trx_id
                                       and rctla.line_type            = 'LINE'
                                       and rctla.customer_trx_line_id = rctlg.customer_trx_line_id
                                       and hp.party_id                = hca.party_id
                                       --and hp.party_name = 'TEST1'
                                       --and hp.party_name = nvl(:p_party_name,hp.party_name)
									   AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                     else 'ZZZ'
                                       end ) = :p_party_id
									   /*AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute2
                                                     else null
                                            end) = :p_party_name*/
                                       --and hca.account_number = nvl(:p_party_name, hca.account_number)
                                       --and trunc(rcta.trx_date) between :p_from_date and :p_to_date
                                       --and rcta.trx_number in ('Test001','REP001')
									   AND hca.account_number = a.account_number(+)
                                       and rcta.customer_trx_id     = a.customer_trx_id(+) -- added v2
                                       and rcta.bill_to_customer_id = a.bill_to_customer_id(+)
                                       and hp.party_name            = a.party_name(+)
                         )
                         b
                group by
                         b.party_name
                       , b.customer_number
                       , b.invoice_number
                       , b.transaction_date
                       , b.gl_date
                       , b.currency
                       , b.transaction_type
                       , b.functional_currency
                       , b.exchange_rate
                       , b.patient_id
                       , b.patient_name
                       , b.plan_name
                       , b.applied_amount
                       , b.functional_applied_amount
       )
       c

union
select
         a.party_name
       , a.customer_number
       , a.receipt_number
       , to_char(a.receipt_date,'DD-MM-YYYY') receipt_date
       , max(to_char(a.gl_date,'DD-MM-YYYY')) gl_date
       , a.currency                           transaction_currency
       , a.transaction_type
       ,(-1)*a.transaction_amount transaction_original_amount
       , a.functional_currency
       , sum(a.transaction_applied_amount)                                    transaction_applied_amount
       ,(-1)*a.Functional_Original_Amount                                     functional_original_amount
       ,(-1)* sum(a.functional_applied_amount)                                transaction_remaining_amount -- transaction_applied_amount
       ,(-1)*(a.Functional_Original_Amount- sum(a.functional_applied_amount)) Functional_Remianing_amount  -- transaction_receipt_remaining_amount
       , a.exchange_rate
       , a.patient_id
       , a.patient_name
       , a.plan_name
from
         (
                select
                       hp.party_name
                     , hca.account_number customer_number
                     , acra.RECEIPT_NUMBER
                     , acra.receipt_date  receipt_date
                     , araa.gl_date       gl_date
                     , acra.currency_code currency
                     , acra.amount        Transaction_Amount
                     ,'KES'               Functional_Currency
                     , CASE
                              WHEN acra.currency_code = 'KES'
                                     THEN null
                                     ELSE
                                          (
                                                 select
                                                        conversion_rate
                                                 from
                                                        gl_daily_rates
                                                 where
                                                        to_currency         = 'KES'
                                                        and from_currency   = acra.currency_code
                                                        and conversion_Date = trunc(acra.receipt_date)
                                     )
                       END EXCHANGE_RATE
                     , CASE
                              WHEN substr(acra.receipt_number,1,2) = 'DR'
                                     THEN 'DEP'
                                     ELSE 'RCPT'
                       END                 Transaction_type
                     , araa.amount_applied transaction_applied_amount
                     , CASE
                              WHEN acra.currency_code = 'KES'
                                     THEN araa.amount_applied
                              WHEN rcta.INVOICE_CURRENCY_CODE = 'KES'
                                     and acra.currency_code  <> 'KES'
                                     THEN araa.amount_applied
                              WHEN rcta.INVOICE_CURRENCY_CODE <> 'KES'
                                     and acra.currency_code   <> 'KES'
                                     THEN araa.amount_applied*
                                     (
                                            select
                                                   conversion_rate
                                            from
                                                   gl_daily_rates
                                            where
                                                   to_currency         = 'KES'
                                                   and from_currency   = acra.currency_code
                                                   and conversion_Date = trunc(acra.receipt_date)
                                     )
                       END Functional_applied_Amount
                     , CASE
                              WHEN acra.currency_code = 'KES'
                                     THEN acra.amount
                                     ELSE acra.amount*
                                     (
                                            select
                                                   conversion_rate
                                            from
                                                   gl_daily_rates
                                            where
                                                   to_currency         = 'KES'
                                                   and from_currency   = acra.currency_code
                                                   and conversion_Date = trunc(acra.receipt_date)
                                     )
                       END             Functional_Original_Amount
                     , acra.attribute1 PATIENT_ID
                     , null            Patient_name
                     , null            Plan_Name
                from
                       AR_CASH_RECEIPTS_ALL           acra
                     , ar_receivable_applications_all araa
                     , ra_customer_trx_all            rcta
                     , hz_cust_accounts               hca
                     , hz_parties                     hp
                where
                       1=1
                       --and rcta.bill_to_customer_id = hca.cust_account_id
                       and ACRA.PAY_FROM_CUSTOMER = HCA.CUST_ACCOUNT_ID(+)
                       and hp.party_id            = hca.party_id
                       --and hp.party_name = 'TEST1'
                       AND ARAA.APPLIED_CUSTOMER_TRX_ID=RCTA.CUSTOMER_TRX_ID
                       and acra.cash_receipt_id        = araa.cash_receipt_id
                       and araa.status                 = 'APP'
                       and acra.status                <> 'REV'
                       --and hp.party_name = nvl(:p_party_name,hp.party_name)
                       --and hca.account_number = nvl(:p_party_name, hca.account_number)
					   AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                     else 'ZZZ'
                                       end ) = :p_party_id					   
                       and trunc(acra.receipt_date) between :p_from_date and :p_to_date
                       --and acra.receipt_number = 'DR103448'
         )
         a
         
         
         where    a.Functional_Original_Amount <>0
group by
         a.party_name
       , a.customer_number
       , a.receipt_number
       , a.receipt_date
       , a.currency
       , a.transaction_type
       , a.transaction_amount
       , a.functional_currency
       , a.Functional_Original_Amount
       , a.exchange_rate
       , a.patient_id
       , a.patient_name
       , a.plan_name
union
select
       y.party_name
     , y.customer_number
     , y.receipt_number
     , y.receipt_date
     , y.gl_date
     , y.transaction_currency
     , y.transaction_type
     , y.transaction_original_amount
     , y.functional_currency
     , y.transaction_applied_amount
     , y.functional_original_amount
     , y.transaction_remaining_amount -- transaction_applied_amount
     , y.Functional_Remianing_amount  -- transaction_receipt_remaining_amount
     , y.exchange_rate
     , y.patient_id
     , y.patient_name
     , y.plan_name
from
       (
                select
                         a.party_name
                       , a.customer_number
                       , a.receipt_number
                       , to_char(a.receipt_date,'DD-MM-YYYY') receipt_date
                       , max(to_char(a.gl_date,'DD-MM-YYYY')) gl_date
                       , a.currency                           transaction_currency
                       , a.transaction_type
                       ,(-1)*a.transaction_amount transaction_original_amount
                       , a.functional_currency
                       , sum(a.transaction_applied_amount)                                           transaction_applied_amount
                       ,(-1)*a.Functional_Original_Amount                                            functional_original_amount
                       ,(-1)* sum(nvl(a.functional_applied_amount,0))                                transaction_remaining_amount -- transaction_applied_amount
                       ,(-1)*(a.Functional_Original_Amount- sum(nvl(a.functional_applied_amount,0))) Functional_Remianing_amount  -- transaction_receipt_remaining_amount
                       , a.exchange_rate
                       , a.patient_id
                       , a.patient_name
                       , a.plan_name
                from
                         (
                                select
                                       hp.party_name
                                     , hca.account_number customer_number
                                     , acra.RECEIPT_NUMBER
                                     , acra.receipt_date  receipt_date
                                     , araa.gl_date       gl_date
                                     , acra.currency_code currency
                                     , acra.amount        Transaction_Amount
                                     ,'KES'               Functional_Currency
                                     , CASE
                                              WHEN acra.currency_code = 'KES'
                                                     THEN null
                                                     ELSE
                                                          (
                                                                 select
                                                                        conversion_rate
                                                                 from
                                                                        gl_daily_rates
                                                                 where
                                                                        to_currency         = 'KES'
                                                                        and from_currency   = acra.currency_code
                                                                        and conversion_Date = trunc(acra.receipt_date)
                                                                        and rownum          =1
                                                     )
                                       END EXCHANGE_RATE
                                     , CASE
                                              WHEN substr(acra.receipt_number,1,2) = 'DR'
                                                     THEN 'DEP'
                                                     ELSE 'RCPT'
                                       END                 Transaction_type
                                     , araa.amount_applied transaction_applied_amount
                                     , CASE
                                              WHEN acra.currency_code = 'KES'
                                                     THEN
                                                     (
                                                              select
                                                                       sum(x.amount_applied)
                                                              from
                                                                       ar_receivable_applications_all x
                                                              where
                                                                       x.cash_receipt_id = acra.cash_receipt_id
                                                                       and x.status      = 'APP'
                                                              group by
                                                                       x.cash_receipt_id
                                                     )
                                                     --araa.amount_applied
                                                     ELSE
                                                          (
                                                                   select
                                                                            sum(x.amount_applied)
                                                                   from
                                                                            ar_receivable_applications_all x
                                                                   where
                                                                            x.cash_receipt_id = acra.cash_receipt_id
                                                                            and x.status      = 'APP'
                                                                   group by
                                                                            x.cash_receipt_id
                                                     )
                                                     *
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = acra.currency_code
                                                                   and conversion_Date = trunc(acra.receipt_date)
                                                                   and rownum          =1
                                                     )
                                       END Functional_applied_Amount
                                     , CASE
                                              WHEN acra.currency_code = 'KES'
                                                     THEN acra.amount
                                                     ELSE acra.amount*
                                                     (
                                                            select
                                                                   conversion_rate
                                                            from
                                                                   gl_daily_rates
                                                            where
                                                                   to_currency         = 'KES'
                                                                   and from_currency   = acra.currency_code
                                                                   and conversion_Date = trunc(acra.receipt_date)
                                                                   and rownum          =1
                                                     )
                                       END             Functional_Original_Amount
                                     , acra.attribute1 PATIENT_ID
                                     , null            Patient_name
                                     , null            Plan_Name
                                from
                                       AR_CASH_RECEIPTS_ALL           acra
                                     , ar_receivable_applications_all araa
                                     , ra_customer_trx_all            rcta
                                     , hz_cust_accounts               hca
                                     , hz_parties                     hp
                                where
                                       1=1
                                       --and rcta.bill_to_customer_id = hca.cust_account_id
                                       and ACRA.PAY_FROM_CUSTOMER = HCA.CUST_ACCOUNT_ID(+)
                                       and acra.status           <> 'REV'
                                       and hp.party_id            = hca.party_id
                                       --and hp.party_name = 'TEST1'
                                       AND ARAA.APPLIED_CUSTOMER_TRX_ID=RCTA.CUSTOMER_TRX_ID(+)
                                       and acra.cash_receipt_id        = araa.cash_receipt_id
                                       and araa.status                 = 'UNAPP'
                                       --and hp.party_name = nvl(:p_party_name,hp.party_name)
                                       --and hca.account_number = nvl(:p_party_name, hca.account_number)
									   AND (CASE
                                              when rcta.attribute_category = 'PATIENT AND SPONSER DETAILS'
                                                     then rcta.attribute1
                                                     else 'ZZZ'
                                       end ) = :p_party_id
                                       and trunc(acra.receipt_date) between :p_from_date and :p_to_date
                                       --and acra.receipt_number = 'DR103448'
                         )
                         a
                group by
                         a.party_name
                       , a.customer_number
                       , a.receipt_number
                       , a.receipt_date
                       , a.currency
                       , a.transaction_type
                       , a.transaction_amount
                       , a.functional_currency
                       , a.Functional_Original_Amount
                       , a.exchange_rate
                       , a.patient_id
                       , a.patient_name
                       , a.plan_name
       )
       y
where
       y.Functional_Original_Amount = y.Functional_Remianing_amount)
       
       
       order  by gl_date desc