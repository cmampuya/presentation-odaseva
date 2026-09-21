"""Candidate management API: a single Lambda function serving the three routes."""

import base64
import binascii
import json
import re
from datetime import date
from email.parser import BytesParser
from email.policy import default as default_policy

from boto3.dynamodb.conditions import Key

from common import (
    BUCKET_NAME,
    MAX_RESUME_SIZE_BYTES,
    PRESIGNED_URL_TTL_SECONDS,
    SPECIALTY_INDEX_NAME,
    ApiError,
    api_handler,
    response,
    s3,
    table,
)

CANDIDATE_ID_PATTERN = re.compile(r"^CA-\d{6,}$")
# Specialty is used in the S3 key: restrict it to a safe character set.
SPECIALTY_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_-]{1,49}$")
NAME_PATTERN = re.compile(r"^[^\x00-\x1f<>\"/\\]{1,100}$")
SEQUENCE_KEY = "#SEQUENCE#candidate"  # never matches CANDIDATE_ID_PATTERN

_ZIP = b"PK\x03\x04"
_OLE = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"
# extension -> (content type, accepted file signatures)
ALLOWED_RESUME_TYPES = {
    "pdf": ("application/pdf", (b"%PDF-",)),
    "doc": ("application/msword", (_OLE,)),
    "docx": ("application/vnd.openxmlformats-officedocument.wordprocessingml.document", (_ZIP,)),
    "ppt": ("application/vnd.ms-powerpoint", (_OLE,)),
    "pptx": ("application/vnd.openxmlformats-officedocument.presentationml.presentation", (_ZIP,)),
    "odt": ("application/vnd.oasis.opendocument.text", (_ZIP,)),
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _parse_multipart(event: dict) -> tuple[dict, dict]:
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    content_type = headers.get("content-type", "")
    if not content_type.lower().startswith("multipart/form-data"):
        raise ApiError(415, "Content-Type must be multipart/form-data")

    body = event.get("body") or ""
    raw = base64.b64decode(body) if event.get("isBase64Encoded") else body.encode("utf-8")
    message = BytesParser(policy=default_policy).parsebytes(
        b"Content-Type: " + content_type.encode("utf-8") + b"\r\nMIME-Version: 1.0\r\n\r\n" + raw
    )
    if not message.is_multipart():
        raise ApiError(400, "Malformed multipart body")

    fields, files = {}, {}
    for part in message.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if not name:
            continue
        payload = part.get_payload(decode=True) or b""
        filename = part.get_filename()
        if filename is not None:
            files[name] = (filename, payload)
        else:
            fields[name] = payload.decode("utf-8", errors="strict").strip()
    return fields, files


def _required(fields: dict, name: str, pattern: re.Pattern) -> str:
    value = fields.get(name, "")
    if not pattern.fullmatch(value):
        raise ApiError(400, f"Missing or invalid field '{name}'")
    return value


def _parse_birth_date(value: str | None) -> str:
    try:
        birth_date = date.fromisoformat(value or "")
    except ValueError as err:
        raise ApiError(400, "Field 'birthDate' must be a date in YYYY-MM-DD format") from err
    if not date(1900, 1, 1) <= birth_date < date.today():
        raise ApiError(400, "Field 'birthDate' is out of range")
    return birth_date.isoformat()


def _validate_resume(filename: str, content: bytes) -> tuple[str, str]:
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in ALLOWED_RESUME_TYPES:
        raise ApiError(400, f"Unsupported resume format. Allowed: {', '.join(sorted(ALLOWED_RESUME_TYPES))}")
    if not content:
        raise ApiError(400, "Resume file is empty")
    if len(content) > MAX_RESUME_SIZE_BYTES:
        raise ApiError(413, f"Resume exceeds {MAX_RESUME_SIZE_BYTES} bytes")
    content_type, signatures = ALLOWED_RESUME_TYPES[extension]
    if not content.startswith(signatures):
        raise ApiError(400, "Resume content does not match its extension")
    return extension, content_type


def _next_candidate_id() -> str:
    """Atomic sequence (DynamoDB ADD) producing CA-000001, CA-000002, ..."""
    result = table.update_item(
        Key={"candidateId": SEQUENCE_KEY},
        UpdateExpression="ADD sequenceValue :one",
        ExpressionAttributeValues={":one": 1},
        ReturnValues="UPDATED_NEW",
    )
    return f"CA-{int(result['Attributes']['sequenceValue']):06d}"


def _to_api(item: dict) -> dict:
    return {
        "candidateId": item["candidateId"],
        "specialty": item["specialty"],
        "firstName": item.get("candidateFirstName"),
        "lastName": item.get("candidateLastName"),
        "birthDate": item.get("candidateBirthDate"),
    }


def _encode_token(key: dict | None) -> str | None:
    return base64.urlsafe_b64encode(json.dumps(key).encode()).decode() if key else None


def _decode_token(token: str, specialty: str) -> dict:
    try:
        key = json.loads(base64.urlsafe_b64decode(token.encode()))
    except (ValueError, binascii.Error) as err:
        raise ApiError(400, "Invalid nextToken") from err
    if (
        not isinstance(key, dict)
        or set(key) != {"candidateId", "specialty"}
        or key["specialty"] != specialty
        or not CANDIDATE_ID_PATTERN.fullmatch(str(key["candidateId"]))
    ):
        raise ApiError(400, "Invalid nextToken")
    return key


# ---------------------------------------------------------------------------
# POST /candidates  (multipart/form-data)
# ---------------------------------------------------------------------------
@api_handler
def create_candidate(event, context):
    fields, files = _parse_multipart(event)
    specialty = _required(fields, "specialty", SPECIALTY_PATTERN)
    first_name = _required(fields, "firstName", NAME_PATTERN)
    last_name = _required(fields, "lastName", NAME_PATTERN)
    birth_date = _parse_birth_date(fields.get("birthDate"))
    if "resume" not in files:
        raise ApiError(400, "Missing file field 'resume'")
    extension, content_type = _validate_resume(*files["resume"])

    candidate_id = _next_candidate_id()
    s3_key = f"{specialty}/{candidate_id}.{extension}"

    upload = s3.put_object(
        Bucket=BUCKET_NAME,
        Key=s3_key,
        Body=files["resume"][1],
        ContentType=content_type,
        ServerSideEncryption="AES256",
        Metadata={"candidate-id": candidate_id},
    )
    item = {
        "candidateId": candidate_id,
        "specialty": specialty,
        "candidateFirstName": first_name,
        "candidateLastName": last_name,
        "candidateBirthDate": birth_date,
        "cvS3Key": s3_key,
    }
    try:
        table.put_item(Item=item, ConditionExpression="attribute_not_exists(candidateId)")
    except Exception:
        # Compensate: do not leave an orphan resume behind.
        s3.delete_object(Bucket=BUCKET_NAME, Key=s3_key, VersionId=upload["VersionId"])
        raise

    return response(201, {**_to_api(item), "resumeKey": s3_key})


# ---------------------------------------------------------------------------
# GET /candidates/{candidateId}
# ---------------------------------------------------------------------------
@api_handler
def get_candidate(event, context):
    candidate_id = (event.get("pathParameters") or {}).get("candidateId", "")
    if not CANDIDATE_ID_PATTERN.fullmatch(candidate_id):
        raise ApiError(400, "Invalid candidateId, expected format CA-000001")

    item = table.get_item(Key={"candidateId": candidate_id}).get("Item")
    if not item:
        raise ApiError(404, "Candidate not found")

    extension = item["cvS3Key"].rsplit(".", 1)[-1]
    download_url = s3.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": BUCKET_NAME,
            "Key": item["cvS3Key"],
            "ResponseContentDisposition": f'attachment; filename="{candidate_id}.{extension}"',
        },
        ExpiresIn=PRESIGNED_URL_TTL_SECONDS,
    )
    return response(
        200,
        {
            **_to_api(item),
            "resume": {
                "key": item["cvS3Key"],
                "downloadUrl": download_url,
                "expiresInSeconds": PRESIGNED_URL_TTL_SECONDS,
            },
        },
    )


# ---------------------------------------------------------------------------
# GET /candidates?specialty=<specialty>[&limit=<n>][&nextToken=<token>]
# ---------------------------------------------------------------------------
@api_handler
def list_candidates(event, context):
    params = event.get("queryStringParameters") or {}
    specialty = params.get("specialty", "")
    if not SPECIALTY_PATTERN.fullmatch(specialty):
        raise ApiError(400, "Missing or invalid query parameter 'specialty'")
    try:
        limit = int(params.get("limit", "20"))
    except ValueError as err:
        raise ApiError(400, "Query parameter 'limit' must be an integer") from err
    if not 1 <= limit <= 100:
        raise ApiError(400, "Query parameter 'limit' must be between 1 and 100")

    query = {
        "IndexName": SPECIALTY_INDEX_NAME,
        "KeyConditionExpression": Key("specialty").eq(specialty),
        "Limit": limit,
    }
    if params.get("nextToken"):
        query["ExclusiveStartKey"] = _decode_token(params["nextToken"], specialty)

    result = table.query(**query)
    items = [_to_api(item) for item in result.get("Items", [])]
    return response(
        200,
        {
            "specialty": specialty,
            "count": len(items),
            "items": items,
            "nextToken": _encode_token(result.get("LastEvaluatedKey")),
        },
    )


# ---------------------------------------------------------------------------
# Entry point: API Gateway proxy integration, one function for every route
# ---------------------------------------------------------------------------

# (HTTP method, API Gateway resource path) -> route handler
ROUTES = {
    ("POST", "/candidates"): create_candidate,
    ("GET", "/candidates/{candidateId}"): get_candidate,
    ("GET", "/candidates"): list_candidates,
}


def handler(event, context):
    route = ROUTES.get((event.get("httpMethod", ""), event.get("resource", "")))
    if route is None:
        request_id = (event.get("requestContext") or {}).get("requestId", "")
        return response(404, {"message": "Route not found", "requestId": request_id})
    return route(event, context)