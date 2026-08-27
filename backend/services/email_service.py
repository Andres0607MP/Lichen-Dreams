"""Email service for sending password reset emails."""

import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SMTP."""

    def __init__(self):
        self.smtp_host = os.getenv("SMTP_HOST", "")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = os.getenv("SMTP_USER", "")
        self.smtp_password = os.getenv("SMTP_PASSWORD", "")
        self.smtp_from = os.getenv("SMTP_FROM", self.smtp_user)
        self.smtp_tls = os.getenv("SMTP_TLS", "true").lower() in ("true", "1", "yes")
        self.backend_url = os.getenv("BACKEND_URL", "http://localhost:8000")

    def is_configured(self) -> bool:
        """Check if SMTP is properly configured."""
        return all([self.smtp_host, self.smtp_user, self.smtp_password])

    def send_email(self, to_email: str, subject: str, html_body: str, text_body: str) -> bool:
        """Send an email to the specified address.
        
        Returns True if email was sent successfully, False otherwise.
        """
        if not self.is_configured():
            logger.warning(
                "SMTP not configured. Email will be logged instead. "
                "To enable email sending, set SMTP_HOST, SMTP_USER, SMTP_PASSWORD in .env"
            )
            logger.info(f"[EMAIL] To: {to_email}")
            logger.info(f"[EMAIL] Subject: {subject}")
            logger.info(f"[EMAIL] Body: {text_body}")
            return True

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = self.smtp_from
            msg["To"] = to_email

            part1 = MIMEText(text_body, "plain")
            part2 = MIMEText(html_body, "html")
            msg.attach(part1)
            msg.attach(part2)

            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                if self.smtp_tls:
                    server.starttls()
                server.login(self.smtp_user, self.smtp_password)
                server.sendmail(self.smtp_from, to_email, msg.as_string())

            logger.info(f"Email sent successfully to {to_email}")
            return True

        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {e}")
            return False

    def send_password_reset_email(self, to_email: str, reset_token: str) -> bool:
        """Send password reset email with the reset token.
        
        The token is presented as a code the user can enter in the app.
        """
        subject = "Lichen Dreams - Recuperación de contraseña"
        
        text_body = f"""
Hola,

Has solicitado restablecer tu contraseña en Lichen Dreams.

Tu código de recuperación es: {reset_token}

Este código expirará en 30 minutos.

Si no solicitaste este cambio, ignora este correo. Tu contraseña seguirá siendo segura.

Saludos,
El equipo de Lichen Dreams
        """.strip()

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #2E7D32;">Lichen Dreams</h2>
        <p>Hola,</p>
        <p>Has solicitado restablecer tu contraseña en <strong>Lichen Dreams</strong>.</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
            <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">Tu código de recuperación es:</p>
            <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2E7D32; margin: 10px 0;">
                {reset_token}
            </p>
            <p style="font-size: 12px; color: #999; margin: 10px 0 0 0;">Este código expirará en 30 minutos.</p>
        </div>
        <p>Si no solicitaste este cambio, ignora este correo. Tu contraseña seguirá siendo segura.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        <p style="font-size: 12px; color: #999;">
            Saludos,<br>
            El equipo de Lichen Dreams
        </p>
    </div>
</body>
</html>
        """.strip()

        return self.send_email(to_email, subject, html_body, text_body)

    def send_verification_email(self, to_email: str, verification_token: str) -> bool:
        """Send email verification email with the verification token.
        
        The token is presented as a code the user can enter in the app.
        """
        subject = "Lichen Dreams - Verificación de correo electrónico"
        
        text_body = f"""
Hola,

Gracias por registrarte en Lichen Dreams.

Tu código de verificación es: {verification_token}

Este código expirará en 60 minutos.

Si no creaste esta cuenta, ignora este correo.

Saludos,
El equipo de Lichen Dreams
        """.strip()

        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #2E7D32;">Lichen Dreams</h2>
        <p>Hola,</p>
        <p>Gracias por registrarte en <strong>Lichen Dreams</strong>.</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0;">
            <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">Tu código de verificación es:</p>
            <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2E7D32; margin: 10px 0;">
                {verification_token}
            </p>
            <p style="font-size: 12px; color: #999; margin: 10px 0 0 0;">Este código expirará en 60 minutos.</p>
        </div>
        <p>Si no creaste esta cuenta, ignora este correo.</p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
        <p style="font-size: 12px; color: #999;">
            Saludos,<br>
            El equipo de Lichen Dreams
        </p>
    </div>
</body>
</html>
        """.strip()

        return self.send_email(to_email, subject, html_body, text_body)


# Singleton instance
email_service = EmailService()
