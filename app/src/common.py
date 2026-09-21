"""Shared helpers: AWS clients, configuration, HTTP responses, error handling."""

import functools
import json
import logging
import os

import boto3
from botocore.config import Config

logger = logging.getLogger()

REGION = os.environ["AWS_REGION"]
TABLE_NAME = os.environ["TABLE_NAME"]
SPECIALTY_INDEX_NAME = os.environ.get("SPECIALTY_INDEX_NAME", "specialty-index")
BUCKET_NAME = os.environ["BUCKET_NAME"]
PRESIGNED_URL_TTL_SECONDS = int(os.environ.get("PRESIGNED_URL_TTL_SECONDS", "300"))
MAX_RESUME_SIZE_BYTES = int(os.environ.get("MAX_RESUME_SIZE_BYTES", str(4 * 1024 * 1024)))

_boto_config = Config(retries={"mode": "standard", "max_attempts": 3})

# Clients are created once per execution environment and reused across invocations.
table = boto3.resource("dynamodb", region_name=REGION, config=_boto_config).Table(TABLE_NAME)

# Regional endpoint + SigV4 + virtual-hosted style: presigned URLs valid in every
# region, and no redirect on newly created buckets.
s3 = boto3.client(
    "s3",
    region_name=REGION,
    endpoint_url=f"https://s3.{REGION}.amazonaws.com",
    config=_boto_config.merge(Config(signature_version="s3v4", s3={"addressing_style": "virtual"})),
)

_SECURITY_HEADERS = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "X-Content-Type-Options": "nosniff",
}


class ApiError(Exception):
    """Client error mapped to an HTTP status code."""

    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


def response(status_code: int, body: dict) -> dict:
    return {"statusCode": status_code, "headers": _SECURITY_HEADERS, "body": json.dumps(body)}


def api_handler(func):
    """Turns exceptions into JSON responses and logs an audit line (no PII)."""

    @functools.wraps(func)
    def wrapper(event, context):
        request_context = event.get("requestContext") or {}
        request_id = request_context.get("requestId", "")
        client_id = ((request_context.get("authorizer") or {}).get("claims") or {}).get("client_id", "")
        audit = {"route": func.__name__, "requestId": request_id, "clientId": client_id}
        try:
            result = func(event, context)
            logger.info("request completed", extra={**audit, "status": result["statusCode"]})
            return result
        except ApiError as err:
            logger.warning("request rejected", extra={**audit, "status": err.status_code, "reason": err.message})
            return response(err.status_code, {"message": err.message, "requestId": request_id})
        except Exception:  # noqa: BLE001 - never leak internals to the caller
            logger.exception("request failed", extra=audit)
            return response(500, {"message": "Internal server error", "requestId": request_id})

    return wrapper
