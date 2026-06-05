"""Gmail SMTP email sender for OTP delivery."""

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587


def _credentials() -> tuple[str, str]:
    """Read credentials lazily so .env reloads are picked up dynamically."""
    from dotenv import load_dotenv
    # Try to load .env relative to this file or from Cwd
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    env_path = os.path.join(base_dir, ".env")
    if os.path.exists(env_path):
        load_dotenv(env_path, override=True)
    else:
        load_dotenv(override=True)
    username = os.getenv("MAIL_USERNAME") or ""
    password = os.getenv("MAIL_PASSWORD") or ""
    return username, password


def send_otp_email(to_email: str, otp: str, purpose: str = "register") -> None:
    """Send a 6-digit OTP to the given email via Gmail SMTP.

    Args:
        to_email: Recipient email address.
        otp: The 6-digit OTP string.
        purpose: 'register' or 'forgot' — controls subject/body text.

    Raises:
        RuntimeError: If SMTP credentials are missing or sending fails.
    """
    mail_username, mail_password = _credentials()

    if not mail_username or not mail_password:
        raise RuntimeError(
            "Missing MAIL_USERNAME or MAIL_PASSWORD in environment variables."
        )

    if purpose == "forgot":
        subject = "ShadowChat X \u2014 Password Reset OTP"
        heading = "Reset Your Password"
        body_text = "Use the OTP below to reset your ShadowChat X password."
    else:
        subject = "ShadowChat X \u2014 Email Verification OTP"
        heading = "Verify Your Email"
        body_text = "Use the OTP below to complete your ShadowChat X registration."

    html = f"""
    <html>
      <body style="font-family:Arial,sans-serif;background:#0a0a0a;padding:32px;">
        <div style="max-width:420px;margin:0 auto;background:#121212;border-radius:16px;
                    border:1px solid #3a3a3a;padding:32px;text-align:center;">
          <h1 style="background:linear-gradient(135deg,#7B2FF7,#3A8DFF);
                     -webkit-background-clip:text;-webkit-text-fill-color:transparent;
                     font-size:28px;margin-bottom:8px;">ShadowChat X</h1>
          <h2 style="color:#fff;font-size:20px;margin-bottom:8px;">{heading}</h2>
          <p style="color:#aaa;font-size:14px;margin-bottom:24px;">{body_text}</p>
          <div style="background:linear-gradient(135deg,#7B2FF7,#3A8DFF);
                      border-radius:12px;padding:20px;display:inline-block;
                      margin-bottom:24px;">
            <span style="color:#fff;font-size:36px;font-weight:900;
                         letter-spacing:10px;">{otp}</span>
          </div>
          <p style="color:#666;font-size:12px;">This OTP expires in <b style="color:#8B5CF6">5 minutes</b>.</p>
          <p style="color:#444;font-size:11px;margin-top:16px;">
            If you did not request this, please ignore this email.
          </p>
        </div>
      </body>
    </html>
    """

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = mail_username
    msg["To"] = to_email
    msg.attach(MIMEText(html, "html"))

    print(f"[DEBUG] Sending OTP email to {to_email} via {SMTP_HOST}:{SMTP_PORT}")
    print(f"[DEBUG] Using MAIL_USERNAME: {mail_username}")

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(mail_username, mail_password)
            server.sendmail(mail_username, to_email, msg.as_string())
        print(f"[DEBUG] OTP email sent successfully to {to_email}")
    except smtplib.SMTPAuthenticationError as e:
        raise RuntimeError(
            f"Gmail SMTP authentication failed. "
            f"Make sure MAIL_PASSWORD is a Gmail App Password (16 chars, no spaces), "
            f"not your normal Gmail password. "
            f"Details: {e}"
        ) from e
    except Exception as e:
        raise RuntimeError(f"Failed to send OTP email: {e}") from e
