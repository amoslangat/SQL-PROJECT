/******************************************************************************************
Date        Developer   Version     Description
07-07-2022  Sushant R   1.0         TKH Doctors Statement Initial Development
25-08-2022  Sushant R   1.1         Added condition to exclude payment with voided status
11-10-2022  Sushant R   1.2         Added NVL to opening balance
*******************************************************************************************/
WITH OPN_BLN AS
     (
	   SELECT  
               nvl(sum( NVL (aida.invoice_amount, i.invoice_amount) - NVL (aipa.invoice_amt_paid, 0) ),0)opening_balance
               ,pv.vendor_id
            FROM  ap_payment_schedules_all ps
               ,  ap_invoices_all i
               ,  poz_suppliers_v  pv
               ,  ap_lookup_codes alc1
               ,  ap_terms_val_v term
               ,  (  SELECT SUM (p.amount + NVL (p.discount_taken, 0)) invoice_amt_paid, p.invoice_id
                       FROM ap_invoice_payments_all p
                      WHERE p.accounting_date <= :p_from_date -1
                   GROUP BY p.invoice_id) aipa
               ,  (  SELECT SUM (d.amount) invoice_amount, d.invoice_id
                       FROM ap_invoice_distributions_all d
                      WHERE d.accounting_date <= :p_from_date -1
                   GROUP BY d.invoice_id) aida
           WHERE i.invoice_id = ps.invoice_id
             AND i.vendor_id = pv.vendor_id
             AND i.cancelled_date IS NULL
             AND alc1.lookup_type(+) = 'INVOICE TYPE'
             AND alc1.lookup_code(+) = i.invoice_type_lookup_code
             AND i.terms_id = term.term_id(+)
             AND i.invoice_id = aipa.invoice_id(+)
            and   i.invoice_date <= :p_from_date -1
             AND pv.vendor_name =  :p_sup_id
           
             AND i.invoice_id = aida.invoice_id(+)
             AND NVL (aida.invoice_amount, i.invoice_amount) - NVL (aipa.invoice_amt_paid, 0) != 0
   group by pv.vendor_id
-----Added by amos
            /*  SELECT
                       NVL( SUM(NVL(accounted_cr, 0))-SUM(NVL(accounted_dr, 0)), 0) opening_balance
                     , supplier.vendor_id
              FROM
                       xla_ae_headers       header
                     , xla_ae_lines         lines
                     , poz_suppliers_v      supplier
                     , poz_supplier_sites_v sites
                     ,
                        --hr_operating_units   ou       ,
                        gl_code_combinations gcc
                     , hz_parties            hp
              WHERE
                       header.ae_header_id       = lines.ae_header_id
                       AND header.application_id = lines.application_id
                       AND supplier.vendor_id    = sites.vendor_id
                       AND sites.vendor_site_id  = lines.party_site_id
                       --AND     ou.organization_id            = sites.prc_bu_id
                       AND lines.code_combination_id     = gcc.code_combination_id
                       AND header.application_id         = 200
                       AND header.balance_type_code      = 'A'
                       AND lines.party_type_code         = 'S'
                       AND header.event_type_code NOT LIKE ( '%PREPAY%' )
                       AND lines.accounting_class_code   = 'LIABILITY'
                       AND supplier.vendor_id            = lines.party_id
                       --and ou.organization_id            = :p_business_unit
                       --AND     supplier.vendor_id = 300000003760733
                       AND hp.party_id                                                               = supplier.party_id
                       AND hp.party_name                                                             = :p_sup_id
                       ----AND TRUNC(TO_DATE(TO_CHAR(lines.accounting_date, 'YYYY-MM-DD'),'YYYY-MM-DD')) < TRUNC(TO_DATE(TO_CHAR(:p_from_date, 'YYYY-MM-DD'),'YYYY-MM-DD'))
              GROUP BY
                       supplier.vendor_id*/
     )
SELECT
         MAIN.ROW_ID
       , MAIN.VENDOR_ID
       , MAIN.REC_TYPE
       , MAIN.sup_name
       , MAIN.sup_num
       , MAIN.trx_num
       , MAIN.patient_name
       , TO_CHAR(MAIN.trx_date,'DD-MM-YYYY') trx_date
       , MAIN.trx_cur
       , MAIN.trx_amt
       , MAIN.trx_unpaid
       , MAIN.trx_deduction
       , MAIN.trx_wht
       , MAIN.P_FROM_DATE
       , MAIN.P_TO_DATE
       , MAIN.OPENING_BALANCE
       , SUM(MAIN.CUMUL_SUM) OVER(ORDER BY MAIN.ROW_ID) AS "TOTALS"
FROM
         (
                SELECT
                       XX_TRN.ROW_ID
                     , XX_TRN.VENDOR_ID
                     , XX_TRN.REC_TYPE
                     , XX_TRN.sup_name
                     , XX_TRN.sup_num
                     , XX_TRN.trx_num
                     , XX_TRN.patient_name
                     , XX_TRN.trx_date
                     , XX_TRN.trx_cur
                     , XX_TRN.trx_amt
                     , XX_TRN.trx_unpaid
                     , XX_TRN.trx_deduction
                     , XX_TRN.trx_wht
                     , XX_TRN.P_FROM_DATE
                     , XX_TRN.P_TO_DATE
                     , NVL(OPN_BLN.OPENING_BALANCE,0) OPENING_BALANCE
                     ,
                        --cumul_sum     ,
                        --SUM(cumul_sum) over(ORDER BY ROW_ID) Totals
                              (
                                     CASE
                                            WHEN 1 = XX_TRN.ROW_ID
                                                   THEN (XX_TRN.CUMUL_SUM+NVL(OPN_BLN.OPENING_BALANCE,0))
                                                   ELSE XX_TRN.CUMUL_SUM
                                     END
                              )
                       CUMUL_SUM
                FROM
                       (
                              SELECT
                                     ROWNUM AS "ROW_ID"
                                   , VENDOR_ID
                                   , REC_TYPE
                                   , sup_name
                                   , sup_num
                                   , trx_num
                                   , patient_name
                                   , trx_date
                                   , trx_cur
                                   , NVL(trx_amt,0)       trx_amt
                                   , NVL(trx_deduction,0) trx_deduction
                                   , NVL(trx_wht,0)       trx_wht
                                   , NVL(trx_unpaid,0)    trx_unpaid
                                   , P_FROM_DATE
                                   , P_TO_DATE
                                   , (NVL(trx_amt,0)+NVL(trx_wht,0)) cumul_sum
                              FROM
                                     (
                                            --Invoice Records
                                            SELECT
                                                   'Invoice' AS "REC_TYPE"
                                                 , ps.vendor_id
                                                 , hp.party_name             sup_name
                                                 , ps.segment1               sup_num
                                                 , TO_CHAR(aia.invoice_num)  trx_num
                                                 , aia.description           patient_name
                                                 , aia.invoice_date          trx_date
                                                 , aia.invoice_currency_code trx_cur
                                                 , aia.invoice_amount        trx_amt
                                                 , apsa.amount_remaining     trx_unpaid
                                                 , (
                                                          SELECT
                                                                 SUM(NVL(ail.amount,0))
                                                          FROM
                                                                 ap_invoice_lines_all ail
                                                          WHERE
                                                                 1                            = 1
                                                                 AND ail.line_type_lookup_code= 'TAX' --As per Requirment
                                                                 AND aia.invoice_id           = ail.invoice_id
                                                   )
                                                                                                             trx_deduction
                                                 , 0                                                         trx_wht
                                                 , TO_DATE(TO_CHAR(:p_from_date, 'YYYY-MM-DD'),'YYYY-MM-DD') P_FROM_DATE
                                                 , TO_DATE(TO_CHAR(:p_to_date, 'YYYY-MM-DD'),'YYYY-MM-DD')   P_TO_DATE
                                            FROM
                                                   ap_invoices_all          aia
                                                 , ap_payment_schedules_all apsa
                                                 , poz_suppliers            ps
                                                 , hz_parties               hp
                                            WHERE
                                                   1                       =1
                                                   AND ps.vendor_id        = aia.vendor_id
                                                   AND apsa.invoice_id     = aia.invoice_id
                                                   AND hp.party_id         = ps.party_id
                                                  AND aia.approval_status in ('APPROVED','AVAILABLE') --VALIDATED INVOICES
                                                /*  AND 'APPROVED'          =
                                                   (
                                                          SELECT
                                                                 ap_invoices_pkg.get_approval_status(aia1.invoice_id,aia1.invoice_amount,aia1.payment_status_flag,aia1.invoice_type_lookup_code)
                                                          FROM
                                                                 ap_invoices_all aia1
                                                          WHERE
                                                                 aia1.invoice_id =aia.invoice_id
                                                   )*/
                                                   AND aia.wfapproval_status IN ( 'WFAPPROVED'
                                                                               , 'NOT REQUIRED'
                                                                               , 'MANUALLY APPROVED')
                                                   AND hp.party_name = :p_sup_id
                                                   AND TRUNC(TO_DATE(TO_CHAR(aia.invoice_date, 'YYYY-MM-DD'),'YYYY-MM-DD')) BETWEEN TRUNC(TO_DATE(TO_CHAR(:p_from_date, 'YYYY-MM-DD'),'YYYY-MM-DD')) AND TRUNC(TO_DATE(TO_CHAR(:p_to_date, 'YYYY-MM-DD'),'YYYY-MM-DD'))
                                            UNION
                                            --Payment Records
                                            SELECT
                                                     'Payment' AS "REC_TYPE"
                                                   , ps.vendor_id
                                                   , hp.party_name                         sup_name
                                                   , ps.segment1                           sup_num
                                                   , TO_CHAR(ipa.payment_reference_number) trx_num
                                                   , NULL                                  patient_name
                                                   , ipa.payment_date                      trx_date
                                                   , aca.currency_code                     trx_cur
                                                   , ipa.payment_amount * -1               trx_amt
                                                   , 0                                     trx_unpaid
                                                   , 0                                     trx_deduction
                                                   , NVL(
                                                          (
                                                                 SELECT
                                                                        SUM(aila.amount)
                                                                 FROM
                                                                        ap_invoice_lines_all    aila
                                                                      , ap_invoice_payments_all aipa
                                                                 WHERE
                                                                        1                             =1
                                                                        AND aipa.invoice_id           = aila.invoice_id
                                                                        AND aipa.check_id             = aca.check_id
                                                                        AND aila.line_type_lookup_code='AWT'
                                                         )
                                                         ,0)                                                   trx_wht
                                                   , TO_DATE(TO_CHAR(:p_from_date, 'YYYY-MM-DD'),'YYYY-MM-DD') P_FROM_DATE
                                                   , TO_DATE(TO_CHAR(:p_to_date, 'YYYY-MM-DD'),'YYYY-MM-DD')   P_TO_DATE
                                            FROM
                                                     ap_checks_all    aca
                                                   , iby_payments_all ipa
                                                   , poz_suppliers    ps
                                                   , hz_parties       hp
                                            WHERE
                                                     1                  =1
                                                     AND ipa.payment_id = aca.payment_id
                                                     --AND     ps.vendor_id   = aipa.REMIT_TO_SUPPLIER_ID
                                                     AND ps.vendor_id = aca.vendor_id
                                                     AND hp.party_id  = ps.party_id
                                                     AND ipa.payment_status NOT IN ('VOID'
                                                                                  ,'VOID_BY_OVERFLOW')-- Added on 25-08-22
                                                     AND hp.party_name = :p_sup_id
                                                     AND TRUNC(TO_DATE(TO_CHAR(ipa.payment_date, 'YYYY-MM-DD'),'YYYY-MM-DD')) BETWEEN TRUNC(TO_DATE(TO_CHAR(:p_from_date, 'YYYY-MM-DD'),'YYYY-MM-DD')) AND TRUNC(TO_DATE(TO_CHAR(:p_to_date, 'YYYY-MM-DD'),'YYYY-MM-DD'))
                                            ORDER BY
                                                     trx_date
                                     )
                       )
                       XX_TRN
                     , OPN_BLN
                WHERE
                       1                   =1
                       AND XX_TRN.VENDOR_ID=OPN_BLN.VENDOR_ID(+)
         )
         MAIN
ORDER BY
         MAIN.trx_date