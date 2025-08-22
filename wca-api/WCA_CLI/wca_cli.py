# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2024. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.


# Assisted by WCA@IBM
# Latest GenAI contribution: ibm/granite-8b-code-instruct
import base64
import os
import re
import sys
import uuid
import json
from pathlib import Path
import requests
import typer


app = typer.Typer(
    name="wca cli", 
    add_completion=False, 
    help="This scripts connects to the IBM WCA service.\r\nSet the environment variable IAM_APIKEY to an apikey that can access the microservice. ",
    no_args_is_help=True)

# WCA api URL (ENV BASE_URL overrides the default value)
DEFAULT_BASE_URL = "https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation"

#IBM IAM URL - to get a token for an APIKEY
DEFAULT_IBM_IAM_URL = "https://iam.cloud.ibm.com/identity/token"
IAM_APIKEY_ENV_PROPERTY = "IAM_APIKEY"

def call_wca_url( payload, file_dict=[], url=os.getenv("BASE_URL", DEFAULT_BASE_URL), request_id=str(uuid.uuid4()), apikey=None):
    """
    Call the Watson Code Assistant API to get a code completion response.

    Parameters:
    - prompt: The code prompt to send to the API.
    - url: The URL of the Watson Code Assistant API. Defaults to the value of the BASE_URL environment variable, or to a default URL if the environment variable is not set.
    - request_id: A unique identifier for the request. Defaults to a randomly generated UUID.
    - apikey: the APIKEY used to authenticate against the url.

    Returns:
    A JSON object containing the code completion response from the API.

    Raises:
    - If the request to the API fails, raises a requests.exceptions.RequestException exception.
    """
    headers = {
        'Authorization': f'Bearer {get_bearer_token(apikey)}',
        'Request-Id': request_id,
        'Origin': 'vscode'
    }

    files = []
    files.append(('message', (None, json.dumps(payload))))
    for a_file in file_dict:
        file_name = a_file.split("/")[-1]
        with open(a_file, 'rb') as file:
            encoded_content = base64.b64encode(file.read()).decode('utf-8')
        files.append(('files', (file_name, encoded_content, 'text/plain')))
    response = requests.post(
        url=url, 
        headers=headers,
        files=files,
        timeout=180
    )
    if not response.ok:
        handle_error(response=response.content,payload=payload,url=url,request_id=request_id)
        response.raise_for_status()
    return response.json()

# Assisted by WCA@IBM
# Latest GenAI contribution: ibm/granite-8b-code-instruct
def handle_error(response, payload, url, request_id):
    """
    Print an error message to stderr.

    Parameters:
    - response (bytes): The response from the API call.
    - payload (dict): The payload from the API call.
    - url (str): The URL of the API call.
    """
    try:
        response_json = json.loads(response.decode('utf-8'))
        print(response_json)
        print(f"Error response from {url}: {request_id}", file=sys.stderr)
        print(f"Payload: {json.dumps(payload, indent=2)}", file=sys.stderr)
        for detail in response_json['detail']:
            print(f"Location: {', '.join(detail['loc'])}", file=sys.stderr)
            print(f"Message: {detail['msg']}", file=sys.stderr)
            print(f"Type: {detail['type']}", file=sys.stderr)
    except Exception as e:
        print(f"Error parsing response: {e}", file=sys.stderr)

# Assisted by WCA@IBM
# Latest GenAI contribution: ibm/granite-8b-code-instruct
def get_bearer_token(apikey=None):
    """
    Returns a bearer token for authentication with IBM Cloud services.
    Uses the apikey specified in the IAM_APIKEY environment property

    Args:
        The apikey=None: The apikey to use for authentication. If not provided, the value of the IAM_APIKEY environment variable is used.

    Returns:
        str: The bearer token
        
    Throws an exception if the bearer cannot be obtained
    """
    if not apikey:
        apikey =  os.getenv(IAM_APIKEY_ENV_PROPERTY)
    headers = {'Content-Type': 'application/x-www-form-urlencoded'}
    data = {'grant_type': 'urn:ibm:params:oauth:grant-type:apikey', 'apikey':apikey}
    response = requests.post(DEFAULT_IBM_IAM_URL, headers=headers, data=data, timeout=30)
    if not response.ok:
        raise Exception(f'Status code: {response.status_code}, Error: {json.loads(response.content)}')
    return response.json()['access_token']

# ############################################################################
#     BUILD PAYLOAD
# ############################################################################
def encode_base64(payload):
    payload_json = json.dumps(payload)
    payload_base64 = base64.b64encode(payload_json.encode('utf-8')).decode('utf-8')
    return payload_base64

def remove_markdown_links(old_text):
    pattern = r'\[([^\]]+)\]\(\1\)'
    modified_text = re.sub(pattern, r'[\1]', old_text)
    
    return modified_text

def build_prompt_paylod(text):
    payload = {
        "message_payload": {
            "messages": [{"content":text, "role": "USER"}],
        }
    }
    return encode_base64(payload)

def build_command_payload(source_file, command):
    payload = {
        "message_payload": {
            "messages": [
                {
                    "content": f"/{command} [{Path(source_file.name).name}](<file-{source_file.name}>)\n",
                    "role": "USER"
                }
            ],
        }
    }
    return encode_base64(payload)

def build_docs_payload(text, command):
    payload = {
        "message_payload": {
            "messages": [
                {
                    "content": f"/{command} {text}\n",
                    "role": "USER"
                }
            ],
        }
    }
    return encode_base64(payload)

# Assisted by WCA@IBM
# Latest GenAI contribution: ibm/granite-8b-code-instruct
def build_unit_test_payload(source_file, command, using, similar_to):

    content_string = f"/{command}"
    if using is not None and using != "":
        content_string += f" using {using}"
    content_string += f" [{Path(source_file.name).name}](<file-{source_file.name}>) "
    if similar_to is not None and using != "":
         content_string += f"similar to [{Path(similar_to.name).name}](<file-{similar_to.name}>) "
    print(f"** COMMAND WILL BE **\r\n{content_string}\r\n**\r\n")    
    payload = {
        "message_payload": {
            "messages": [
                {
                    "content": content_string,
                    "role": "USER"
                }
            ],
            "settings": {}
        }
    }
    return encode_base64(payload)

# Assisted by WCA@IBM
# Latest GenAI contribution: ibm/granite-8b-code-instruct
def build_translate_payload(source_file, command, from_l, to_l):
    payload = f"{command}"
    if from_l is not None and from_l != "":
        payload += f" from {from_l}"
    payload += f" to {to_l}"

    return build_command_payload(source_file, payload)


# ############################################################################
#     UTIL COMMANDS
# ############################################################################


# ##################### STRINGS
SUB_SIMILAR="The requested code suggestion is similar to code found in file: [{file}] licensed under [{license}]."+os.linesep
REJECT_UNKNOWN = "The code suggestion that you requested has been blocked"
REJECT_BLOCK = os.linesep+"WCA001:"+SUB_SIMILAR+"The suggestions has been blocked. If you want the suggestion use --force"+os.linesep
REJECT_BLOCK_customer = os.linesep+"WCA002:"+SUB_SIMILAR+"Your administrator has blocked such suggestions. If you want the suggestion use --force"+os.linesep
REJECT_WARNING_customer = os.linesep+"WCA003:"+SUB_SIMILAR+"Your administrator has not authorized such license. If you want the suggestion, allow the license using the allowed-licenses parameter"+os.linesep
ALLOW_WARNING = os.linesep+"** WARNING **"+os.linesep+SUB_SIMILAR+"The license is on the list of allowed licenses and will be returned."+os.linesep


# Assisted by WCA@IBM
# Latest GenAI contribution: ibm/granite-8b-code-instruct
def check_blocked_for_similarity(response_payload, allowed_licenses_str='{}'):
    """
    Check if the response payload indicates that the generated response is blocked due to a similarity match with the data that was used for training the model

    Parameters:
    - response_payload (dict): The response payload from the API call.
    - allowed_licenses_str (str): A string of allowed licenses separated by commas.

    Returns:
    - Tuple[bool, str]: A tuple containing a boolean indicating whether the generated response is blocked and a string message indicating the reason for the rejection.
    """
    response_json = response_payload['response']
    if 'similarity_matches' in response_json:
        similarity_matches = response_json['similarity_matches']
        if similarity_matches and len(similarity_matches) > 0:
            for match in similarity_matches:
                if match['action_status'] == 'BLOCK':
                    if match['origin'] == 'IBM':
                        return True, (REJECT_BLOCK.replace("{file}",match['uri']).replace("{license}",",".join(match['license'])))
                    else:
                        return True, (REJECT_BLOCK_customer.replace("{file}",match['uri']).replace("{license}",",".join(match['license'])))
                if match['action_status'] == 'WARNING':
                    allowed_licenses_json = allowed_licenses_str.split(",")
                    if all(item in allowed_licenses_json  for item in match['license']):
                        return False, (ALLOW_WARNING.replace("{file}",match['uri']).replace("{license}",",".join(match['license'])))
                    else:
                        return True,(REJECT_WARNING_customer.replace("{file}",match['uri']).replace("{license}",",".join(match['license'])))
            return True, REJECT_UNKNOWN
    return False, None


# ############################################################################
#     TYPER COMMAND
# ############################################################################

@app.command()
def prompt(
    prompt_str: str  = typer.Argument(..., help="The prompt to pass the model."),
    source_file: typer.FileText = typer.Option(default=None, help="The source file passed in the prompt."),
    iam_apikey: str = typer.Option(None, envvar=IAM_APIKEY_ENV_PROPERTY, help="The APIKEY used for authentication and authorization. Uses environment property by default."),
    allowed_licenses: str = typer.Option(default=None, help="comma separated list of allowed licenses. eg \"mitlicense,Apache2.0\""),
    to_file: typer.FileTextWrite = typer.Option(default=None, help="File to write the response.")):
    """
    Prompt the Watson Code Assistant (WCA) model with a given string.

    Args:
        prompt_str (str): The prompt to pass to the WCA model.
        allowed_licenses (str): A comma-separated list of allowed licenses. Defaults to "".
        to_file (typer.FileTextWrite): Optional file to write the response to. Defaults to None.

    Returns:
        str: The content of the response from prompting WCA.
    """
    # call service
    response = call_wca_url(build_prompt_paylod(prompt_str),apikey=iam_apikey,file_dict=[source_file.name] if source_file else [])
    is_blocked, blocked_msg = check_blocked_for_similarity(response, allowed_licenses) 
    if is_blocked:
        print(blocked_msg,file=sys.stderr)
        exit(77)
    print(response['response']['message']['content'])
    if response['error'] and response['response']['message']['content'] != response['error']['message']:
        print(response['error']['message'])
    if to_file:
        to_file.write(json.dumps(response['response']))

@app.command()
def docs(
    docs_query: str  = typer.Argument(..., help="The prompt to pass the model. This will query documentation."),
    iam_apikey: str = typer.Option(None, envvar=IAM_APIKEY_ENV_PROPERTY, help="The APIKEY used for authentication and authorization. Uses environment property by default."),
    to_file: typer.FileTextWrite = typer.Option(default=None, help="File to write the response.")):
    """Query on IBM or Redhat product documentation"""
    # call service
    response = call_wca_url(build_docs_payload(docs_query, "docs"),apikey=iam_apikey)
    response['response']['message']['content'] = remove_markdown_links(response['response']['message']['content'])
    print(response['response']['message']['content'])
    if response['error'] and response['response']['message']['content'] != response['error']['message']:
        print(response['error']['message'])
    if to_file:
        to_file.write(json.dumps(response['response']))

@app.command()
def explain(
    source_file: typer.FileText = typer.Argument(..., help="The source code to explain."),
    iam_apikey: str = typer.Option(None, envvar=IAM_APIKEY_ENV_PROPERTY, help="The APIKEY used for authentication and authorization. Uses environment property by default."),
    to_file: typer.FileTextWrite = typer.Option(default=None, help="File to write the response.")):
    """Explain a code reference or code snippet from a source_file.

    Args:
        source_file (typer.FileText): The source code file to explain.

    Returns:
        str: The explanation of the code.
    """
    # call service
    response = call_wca_url(build_command_payload(source_file,"explain"),file_dict=[source_file.name],apikey=iam_apikey)
    print(response['response']['message']['content'])
    if response['error'] and response['response']['message']['content'] != response['error']['message']:
        print(response['error']['message'])
    if to_file:
        to_file.write(json.dumps(response['response']))


@app.command()
def document(
    source_file: typer.FileText = typer.Argument(..., help="The source code to document."),
    iam_apikey: str = typer.Option(None, envvar=IAM_APIKEY_ENV_PROPERTY, help="The APIKEY used for authentication and authorization. Uses environment property by default."),
    to_file: typer.FileTextWrite = typer.Option(default=None, help="File to write the response.")):
    """Generate language-specific documentation for a code reference from a source_file.
    """

    # call service
    response = call_wca_url(build_command_payload(source_file,"document"),file_dict=[source_file.name],apikey=iam_apikey)
    print(response['response']['message']['content'])
    if response['error'] and response['response']['message']['content'] != response['error']['message']:
        print(response['error']['message'])
    if to_file:
        to_file.write(json.dumps(response['response']))

@app.command()
def unit_test(
    source_file: typer.FileText = typer.Argument(..., help="The source code used to create a unit test."),
    using: str = typer.Option("",help="The unite test frameowkr to use. If none is passed, the default for taht language will be used."),
    similar_to:  typer.FileText = typer.Option(None, help="File that provides an example of how the generated unit tests are expected to look."),
    iam_apikey: str = typer.Option(None, envvar=IAM_APIKEY_ENV_PROPERTY, help="The APIKEY used for authentication and authorization. Uses environment property by default."),
    to_file: typer.FileTextWrite = typer.Option(default=None, help="File to write the response.")):
    """Generate unit tests for a code reference or a code snippet from a source_file. """
    # call service
    response = call_wca_url(build_unit_test_payload(
        source_file=source_file,
        command="unit-test",
        using=using,
        similar_to=similar_to),file_dict= [x.name for x in [source_file,similar_to] if x],apikey=iam_apikey)
    print(response['response']['message']['content'])
    if response['error'] and response['response']['message']['content'] != response['error']['message']:
        print(response['error']['message'])
    if to_file:
        to_file.write(json.dumps(response['response']))


@app.command()
def translate(
    source_file: typer.FileText = typer.Argument(..., help="The source code used to create a unite test."),
    to_language: str = typer.Option(..., "--to",help="The Target language to translate to."),
    from_language: str = typer.Option(None, "--from", help="The Source language to translate from. If none is provided, the system will attempt to detect it"),
    iam_apikey: str = typer.Option(None, envvar=IAM_APIKEY_ENV_PROPERTY, help="The APIKEY used for authentication and authorization. Uses environment property by default."),
    to_file: typer.FileTextWrite = typer.Option(default=None, help="File to write the response.")):
    """Translate a code reference from one programming language to another from a source_file."""
    # call service
    response = call_wca_url(build_translate_payload(source_file,command="translate",from_l=from_language,to_l=to_language),file_dict=[source_file.name],apikey=iam_apikey)
    print(response['response']['message']['content'],to_file)
    if response['error'] and response['response']['message']['content'] != response['error']['message']:
        print(response['error']['message'])
    if to_file:
        to_file.write(json.dumps(response['response']))

if __name__ == "__main__":
    app()
