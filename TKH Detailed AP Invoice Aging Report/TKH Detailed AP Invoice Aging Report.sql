SELECT
  vendor_name,
  supp_no,
  invoice_num,
:p_as_on_date,
  invoice_type,
  invoice_date,
  nvl (amt_due_remaining, 0) amt_due_remaining,
  nvl(current_Month, 0) current_Month,
  nvl(Month_1, 0) Month_1,
  nvl(Month_2, 0) Month_2,
  nvl(Month_3, 0) Month_3,
  nvl(Month_abve_3, 0) Month_abve_3
from
  (
    SELECT
      vendor_name,
      supp_no,
      invoice_num,
      invoice_type,
      invoice_date,
      amt_due_remaining,
      CASE
        WHEN past_due_days <= 30 THEN amt_due_remaining
        ELSE NULL
      END current_Month,
      CASE
        WHEN past_due_days > 30
        AND past_due_days <= 60 THEN amt_due_remaining
        ELSE NULL
      END Month_1,
      CASE
        WHEN past_due_days > 60
        AND past_due_days <= 90 THEN amt_due_remaining
        ELSE NULL
      END Month_2,
      CASE
        WHEN past_due_days > 90
        AND past_due_days <= 120 THEN amt_due_remaining
        ELSE NULL
      END Month_3,
      CASE
        WHEN past_due_days > 120 THEN amt_due_remaining
        ELSE NULL
      END Month_abve_3
    FROM
      (
        SELECT
          v.vendor_name,
          i.invoice_date,
          i.invoice_num,
          i.INVOICE_TYPE_LOOKUP_CODE invoice_type,
          v.segment1 supp_no,
          CEIL(
            TO_DATE(
              TO_CHAR(:p_as_on_date, 'DD-MON-RRRR'),
              'DD-MON-RRRR'
            ) - i.invoice_date
          ) as past_due_days,
           (nvl(atb.accounted_dr,0)- nvl(atb.accounted_cr,0) ) *(-1) amt_due_remaining
          --ps.amount_remaining as amt_due_remaining
        FROM
          ap_payment_schedules_all ps,
          ap_invoices_all i,
          poz_suppliers_v v,
          poz_supplier_sites_all_m vs,
         ap_trial_balances  atb
        WHERE
          i.invoice_id = ps.invoice_id
          AND i.vendor_id = v.vendor_id
          AND atb.invoice_id = ps.invoice_id
          AND i.vendor_id = atb.vendor_id
        AND atb.vendor_id = v.vendor_id
          AND i.vendor_site_id = vs.vendor_site_id
          AND i.payment_status_flag IN ('N','P')
          and i.invoice_date < :p_as_on_date
          AND v.vendor_name = nvl(:p_vendor_name, v.vendor_name)
          AND v.segment1 = nvl(:p_vendor_num, v.segment1)
          AND (
            NVL(ps.amount_remaining, 0) * NVL(i.exchange_rate, 1)
          ) != 0
          AND i.cancelled_date is null
        ORDER BY
          i.INVOICE_DATE asc
      )
  )