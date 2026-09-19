import { Component } from "inferno";
import { NavLink } from "inferno-router";
import { GetSiteResponse } from "lemmy-js-client";
import { instanceLabel, sourceCodeLabel, sourceCodeUrl } from "@utils/config";
import { setIsoData } from "@utils/app";
import { amAdmin } from "@utils/roles";
import { I18NextService } from "../../services";
import { VERSION } from "../../version";

interface FooterProps {
  site?: GetSiteResponse;
}

export class Footer extends Component<FooterProps, never> {
  private isoData = setIsoData(this.context);

  render() {
    // LOCAL: the UI/BE version badges are useful when debugging but are developer noise on a
    // public site, so only admins see them.
    const showVersions = amAdmin(this.isoData.myUserInfo);

    return (
      <footer className="app-footer container-lg navbar navbar-expand-md navbar-light navbar-bg p-3">
        <div className="navbar-collapse">
          <ul className="navbar-nav ms-auto">
            {showVersions && (
              <>
                {this.props.site?.version !== VERSION && (
                  <li className="nav-item">
                    <span className="nav-link">UI: {VERSION}</span>
                  </li>
                )}
                <li className="nav-item">
                  <span className="nav-link">
                    BE: {this.props.site?.version}
                  </span>
                </li>
              </>
            )}
            <li className="nav-item">
              <NavLink className="nav-link" to="/modlog">
                {I18NextService.i18n.t("modlog")}
              </NavLink>
            </li>
            {this.props.site?.site_view.local_site.legal_information && (
              <li className="nav-item">
                <NavLink className="nav-link" to="/legal">
                  {I18NextService.i18n.t("legal_information")}
                </NavLink>
              </li>
            )}
            {this.props.site?.site_view.local_site.federation_enabled && (
              <li className="nav-item">
                <NavLink className="nav-link" to="/instances">
                  {I18NextService.i18n.t("instances")}
                </NavLink>
              </li>
            )}
            {/* LOCAL: dropped the docs link, the code link and the join-lemmy.org link, and
                show the site name as plain text instead. */}
            <li className="nav-item">
              <span className="nav-link">{instanceLabel}</span>
            </li>
            {/* LOCAL: AGPL requires offering the source of this modified version. */}
            <li className="nav-item">
              <a
                className="nav-link"
                href={sourceCodeUrl}
                target="_blank"
                rel="noopener noreferrer"
              >
                {sourceCodeLabel}
              </a>
            </li>
          </ul>
        </div>
      </footer>
    );
  }
}
