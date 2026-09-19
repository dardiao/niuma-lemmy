import { getStaticDir } from "@utils/env";

export const favIconUrl = `${getStaticDir()}/assets/icons/favicon.svg`;
export const favIconPngUrl = `${getStaticDir()}/assets/icons/apple-touch-icon.png`;

export const archiveTodayUrl = "https://archive.today";
export const ghostArchiveUrl = "https://ghostarchive.org";
export const webArchiveUrl = "https://web.archive.org";
export const matrixUrl = "https://matrix.org/try-matrix/";

// --- LOCAL customization ---------------------------------------------------------------
// Site-specific strings for this deployment. Kept together and marked with LOCAL: so it is
// obvious what to re-check when rebasing onto a newer upstream.
export const instanceLabel = "niuma.club";
export const copyLinkLabel = "复制链接";
export const copiedLabel = "已复制";
// AGPL 第 13 条要求向使用者提供本修改版的源码，页脚链接指向公开仓库。
export const sourceCodeUrl = "https://github.com/dardiao/niuma-lemmy";
export const sourceCodeLabel = "源代码";
// Signup is tied to the operator's subdomain platform: a username is the prefix of a
// registered `<prefix>.niuma.club`, verified through the proxy in the ui server.
export const signupDomainSuffix = "niuma.club";
export const domainCheckPath = "/domain-check";
export const domainCheckMessages = {
  checking: "正在校验子域名…",
  ok: "子域名已注册 ✅",
  // Lemmy 用户名只允许字母、数字、下划线，长度 2~20；带连字符的子域名不能作为用户名。
  invalid: "只能用字母、数字、下划线，长度 2~20（连字符不支持）",
  unavailable: "暂时无法校验，提交后由管理员核对",
  // 未注册时的提示：中间那段是可点击的链接，直接跳到 HapDNS 首页。
  unregistered: {
    text: "这个子域名还没有注册，请先去 ",
    link: { text: "HapDNS", href: "https://hapdns.com/" },
    tail: " 注册",
  },
};

export const postRefetchSeconds: number = 60 * 1000;
export const mentionDropdownFetchLimit = 10;
export const commentTreeMaxDepth = 8;
export const postMarkdownFieldCharacterLimit = 50000;
export const markdownFieldCharacterLimit = 10000;
export const maxUploadImages = 20;
export const concurrentImageUpload = 4;
export const updateUnreadCountsInterval = 30000;
export const fetchLimit = 20;
export const similarPostFetchLimit = 6;
export const relTags = "noopener nofollow";
export const emDash = "\u2014";
export const authCookieName = "jwt";
export const adultConsentCookieKey = "adultConsent";

// No. of max displayed communities per
// page on route "/communities"
export const communityLimit = 50;
export const multiCommunityLimit = 50;

const queryPairRegex = "[a-zA-Zd_-]+=[a-zA-Zd+-_]+";

/**
 * Accepted formats:
 * !community@server.com
 * /c/community@server.com
 * /m/community@server.com
 * /u/username@server.com
 * @username@server.com
 */
export const instanceLinkRegex = new RegExp(
  `(/[cmu]/|!|@)[a-zA-Z\\d._%+-]+@[a-zA-Z\\d.-]+\\.[a-zA-Z]{2,}(?:/?\\?${queryPairRegex}(?:&${queryPairRegex})*)?`,
  "g",
);

export const testHost = "localhost:8536";

export const validActorRegexPattern =
  "^\\w+|[\\p{Script=Arabic}\\d_]+|[\\p{Script=Cyrillic}\\d_]+$";
