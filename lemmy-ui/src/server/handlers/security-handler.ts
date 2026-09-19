import type { Response } from "express";
import { BUILD_DATE_ISO8601 } from "../../shared/build-date";
import { parseISO } from "date-fns";

// LOCAL: upstream pointed this at its own security advisory page. Send reporters to the
// operator instead: set LEMMY_UI_SECURITY_CONTACT (a uri, e.g. mailto:you@example.org) in the
// deployment. With nothing configured only the Expires field is sent, so no report ever ends
// up at the upstream project by accident.
export default ({ res }: { res: Response }) => {
  const buildDatePlusYear = parseISO(BUILD_DATE_ISO8601);

  // Add a year to the build date
  buildDatePlusYear.setFullYear(new Date().getFullYear() + 1);

  const yearFromNow = buildDatePlusYear.toISOString();

  res.setHeader("content-type", "text/plain; charset=utf-8");

  const contact = process.env.LEMMY_UI_SECURITY_CONTACT;
  res.send(
    contact
      ? `Contact: ${contact}\nExpires: ${yearFromNow}`
      : `Expires: ${yearFromNow}`,
  );
};
