# Using curl to access the WCA API

### Pre-requisites:
1.  An IAM  access token has to be generated for authentication and authorization purposes. Please use your WCA Cloud API key to generate the token. Please refer to this documentation for details on how to generate the token using the API Key : https://cloud.ibm.com/apidocs/watson-data-api#creating-an-iam-bearer-token
2.  Update the provided sample payloads with the right prompt that you wish to use while accessing the WCA API.

All text generation use cases are available through a single endpoint. What differs is the payload for the endpoint. Sample payloads have been provided for the following use cases: 

- Basic chat (without file referencing)
- Chat with history for context
- /document command
- /explain command
- /unit test command
- /translate command
- /docs command

#### Curl Command for Text Generation
```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: <request-id>' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat <path/message_payload.json> | base64)" \
  --form files=@<(echo $(base64 -i path/to/referenced_file | tr -d '\n') )
```
Note: 
- access_token is mandatory. It is the IAM token generated using the IBM Cloud API Key.
- request-id is optional and it refers to a uuid that is used to uniquely identify the request. It is recommended that users provide a uuid as a best practice. This enables the request to be traced through the system, when there is a need to do so,  for example for tracking or debugging purposes.
- files attribute is optional. It is used when one or more file contents need to be passed as context for the prompt.

##### Examples

Basic chat without any file references or commands : 

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1a' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/simple_chat.json | base64)"
```

##### Expected Response
```
{
"request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1a",
"response": {
"augmented_prompt": "",
"generated_response": "",
"create_ts": "2024-12-09T04:22:44.032057",
"message": {
"role": "ASSISTANT",
"content": "Sure! Here's a program in Python that adds two numbers:\n\npython\n# Assisted by watsonx Code Assistant \nnum1 = 5\nnum2 = 10\n\nsum = num1 + num2\nprint(\"The sum of\", num1, \"and\", num2, \"is\", sum)\n\n\nThis program defines two variables num1 and num2 with the values 5 and 10 respectively. It then adds these two numbers together and stores the result in a new variable called sum. Finally, it prints out the result using the print() function.",
"type": "CHAT",
"context": "",
"use_for_context": true
},
"similarity_matches": [],
"model": "ibm/granite-8b-code-instruct"
},
"error": null
}
```

#### Basic chat with history as context

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1b' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/chat_with_history.json | base64)"
```

##### Expected Response
```
{
"request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1b",
"response": {
"augmented_prompt": "",
"generated_response": "",
"create_ts": "2024-12-09T04:26:25.119358",
"message": {
"role": "ASSISTANT",
"content": "java\n// Assisted by watsonx Code Assistant \nimport org.junit.Test;\nimport static org.junit.Assert.*;\n\npublic class QuickSortTest {\n    @Test\n    public void testQuickSort() {\n        int[] arr = { 10, 7, 8, 9, 1, 5 };\n        quickSort(arr, 0, arr.length - 1);\n        assertArrayEquals(new int[]{ 1, 5, 7, 8, 9, 10 }, arr);\n    }\n\n    private void quickSort(int[] arr, int low, int high) {\n        if (low < high) {\n            int pi = partition(arr, low, high);\n            quickSort(arr, low, pi - 1);\n            quickSort(arr, pi + 1, high);\n        }\n    }\n\n    private int partition(int[] arr, int low, int high) {\n        int pivot = arr[high];\n        int i = low - 1;\n        for (int j = low; j <= high - 1; j++) {\n            if (arr[j] <= pivot) {\n                i++;\n                int temp = arr[i];\n                arr[i] = arr[j];\n                arr[j] = temp;\n            }\n        }\n        int temp = arr[i + 1];\n        arr[i + 1] = arr[high];\n        arr[high] = temp;\n        return i + 1;\n    }\n}\n",
"type": "CHAT",
"context": "",
"use_for_context": true
},
"similarity_matches": [],
"model": "ibm/granite-8b-code-instruct"
},
"error": null
}
```

#### Explain command

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1c' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/explain_command.json | base64)" \
  --form files=@<(echo $(base64 -i rest_api/customer.py | tr -d '\n') )
```

##### Expected Response
```
{
	"request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1c",
	"response": {
		"augmented_prompt": "",
		"generated_response": "",
		"create_ts": "2024-12-09T12:45:06.339884",
		"message": {
			"role": "ASSISTANT",
			"content": "The code defines a class `Customer` with an `__init__` method that initializes the `name` and `age` attributes. It also has a `check_eligibility` method that checks if the customer is eligible based on the age. The `main` function prompts the user to enter the customer's name and age, creates a `Customer` object, and calls the `check_eligibility` method to determine if the customer is eligible.\n\n ",
			"type": "EXPLANATION",
			"context": "```python\n//customer.py\nclass Customer:\n    def __init__(self, name, age):\n        self.name = name\n        self.age = age\n\n    def check_eligibility(self):\n        if self.age > 18:\n            return f\"{self.name} is eligible.\"\n        else:\n            return f\"{self.name} is not eligible.\"\n\ndef main():\n    # Input: Customer's name and age\n    name = input(\"Enter customer's name: \")\n    age = int(input(\"Enter customer's age: \"))\n\n    # Create Customer object\n    customer = Customer(name, age)\n\n    # Check eligibility\n    print(customer.check_eligibility())\n\nif __name__ == \"__main__\":\n    main()\n```\n\n",
			"use_for_context": true
		},
		"similarity_matches": [],
		"model": "ibm/granite-8b-code-instruct"
	},
	"error": null
}
```

#### Document Command

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1d' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/document_command.json | base64)" \
  --form files=@<(echo $(base64 -i rest_api/customer.py | tr -d '\n') )
```


##### Expected Response
```
{
	"request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1d",
	"response": {
		"augmented_prompt": "",
		"generated_response": "",
		"create_ts": "2024-12-09T12:46:34.496245",
		"message": {
			"role": "ASSISTANT",
			"content": "```python\n# Assisted by watsonx Code Assistant \nclass Customer:\n    \"\"\"\n    A class to represent a customer with name and age.\n\n    Attributes:\n        name (str): The name of the customer.\n        age (int): The age of the customer.\n\n    Methods:\n        check_eligibility(self): Checks if the customer is eligible based on age.\n\n    \"\"\"\n    def __init__(self, name, age):\n        self.name = name\n        self.age = age\n\n    def check_eligibility(self):\n        \"\"\"\n        Checks if the customer is eligible based on age.\n\n        Returns:\n            str: A message indicating whether the customer is eligible or not.\n        \"\"\"\n        if self.age > 18:\n            return f\"{self.name} is eligible.\"\n        else:\n            return f\"{self.name} is not eligible.\"\n\ndef main():\n    \"\"\"\n    Main function to interact with the Customer class.\n\n    Prompts the user to enter customer's name and age,\n    creates a Customer object, and checks eligibility.\n    \"\"\"\n    # Input: Customer's name and age\n    name = input(\"Enter customer's name: \")\n    age = int(input(\"Enter customer's age: \"))\n\n    # Create Customer object\n    customer = Customer(name, age)\n\n    # Check eligibility\n    print(customer.check_eligibility())\n\nif __name__ == \"__main__\":\n    main()\n```",
			"type": "DOCUMENTATION",
			"context": "```python\n//customer.py\nclass Customer:\n    def __init__(self, name, age):\n        self.name = name\n        self.age = age\n\n    def check_eligibility(self):\n        if self.age > 18:\n            return f\"{self.name} is eligible.\"\n        else:\n            return f\"{self.name} is not eligible.\"\n\ndef main():\n    # Input: Customer's name and age\n    name = input(\"Enter customer's name: \")\n    age = int(input(\"Enter customer's age: \"))\n\n    # Create Customer object\n    customer = Customer(name, age)\n\n    # Check eligibility\n    print(customer.check_eligibility())\n\nif __name__ == \"__main__\":\n    main()\n```\n\n",
			"use_for_context": true
		},
		"similarity_matches": [],
		"model": "ibm/granite-8b-code-instruct"
	},
	"error": null
}
```

#### Unit Test Command
```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1e' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/unit-test_command.json | base64)" \
  --form files=@<(echo $(base64 -i rest_api/customer.py | tr -d '\n') )
```

##### Expected Response
```
{
	"request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1e",
	"response": {
		"augmented_prompt": "",
		"generated_response": "",
		"create_ts": "2024-12-09T12:47:00.733722",
		"message": {
			"role": "ASSISTANT",
			"content": "```python\n# Assisted by watsonx Code Assistant \nimport unittest\nfrom customer import Customer\n\nclass TestCustomer(unittest.TestCase):\n    def test_init(self):\n        customer = Customer(\"John\", 20)\n        self.assertEqual(customer.name, \"John\")\n        self.assertEqual(customer.age, 20)\n\n    def test_check_eligibility(self):\n        customer = Customer(\"John\", 20)\n        self.assertEqual(customer.check_eligibility(), \"John is eligible.\")\n\n        customer = Customer(\"Jane\", 16)\n        self.assertEqual(customer.check_eligibility(), \"Jane is not eligible.\")\n\nif __name__ == \"__main__\":\n    unittest.main()\n```",
			"type": "TEST_GENERATION",
			"context": "```python\n//customer.py\nclass Customer:\n    def __init__(self, name, age):\n        self.name = name\n        self.age = age\n\n    def check_eligibility(self):\n        if self.age > 18:\n            return f\"{self.name} is eligible.\"\n        else:\n            return f\"{self.name} is not eligible.\"\n\ndef main():\n    # Input: Customer's name and age\n    name = input(\"Enter customer's name: \")\n    age = int(input(\"Enter customer's age: \"))\n\n    # Create Customer object\n    customer = Customer(name, age)\n\n    # Check eligibility\n    print(customer.check_eligibility())\n\nif __name__ == \"__main__\":\n    main()\n```\n\n",
			"use_for_context": true
		},
		"similarity_matches": [
			{
				"action_status": "NO_SIMILARITY",
				"title": "",
				"repo_name": "",
				"uri": "",
				"score": 0.0,
				"license": [],
				"line_number": -1,
				"origin": "IBM"
			}
		],
		"model": "ibm/granite-8b-code-instruct"
	},
	"error": null
}
```

#### Translate Command

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1f' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/translate_command.json | base64)" \
  --form files=@<(echo $(base64 -i rest_api/customer.py | tr -d '\n') )
```

##### Expected Response
```
{
	"request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1f",
	"response": {
		"augmented_prompt": "",
		"generated_response": "",
		"create_ts": "2024-12-09T12:48:02.787351",
		"message": {
			"role": "ASSISTANT",
			"content": "```java\n// Assisted by watsonx Code Assistant \n//Customer.java\npublic class Customer {\n    private String name;\n    private int age;\n\n    public Customer(String name, int age) {\n        this.name = name;\n        this.age = age;\n    }\n\n    public String checkEligibility() {\n        if (this.age > 18) {\n            return name + \" is eligible.\";\n        } else {\n            return name + \" is not eligible.\";\n        }\n    }\n\n    public static void main(String[] args) {\n        // Input: Customer's name and age\n        Scanner scanner = new Scanner(System.in);\n        System.out.print(\"Enter customer's name: \");\n        String name = scanner.nextLine();\n        System.out.print(\"Enter customer's age: \");\n        int age = scanner.nextInt();\n\n        // Create Customer object\n        Customer customer = new Customer(name, age);\n\n        // Check eligibility\n        System.out.println(customer.checkEligibility());\n    }\n}\n```",
			"type": "CODE_TRANSLATE",
			"context": "```python\n//customer.py\nclass Customer:\n    def __init__(self, name, age):\n        self.name = name\n        self.age = age\n\n    def check_eligibility(self):\n        if self.age > 18:\n            return f\"{self.name} is eligible.\"\n        else:\n            return f\"{self.name} is not eligible.\"\n\ndef main():\n    # Input: Customer's name and age\n    name = input(\"Enter customer's name: \")\n    age = int(input(\"Enter customer's age: \"))\n\n    # Create Customer object\n    customer = Customer(name, age)\n\n    # Check eligibility\n    print(customer.check_eligibility())\n\nif __name__ == \"__main__\":\n    main()\n```\n\n",
			"use_for_context": true
		},
		"similarity_matches": [
			{
				"action_status": "NO_SIMILARITY",
				"title": "",
				"repo_name": "",
				"uri": "",
				"score": 0.0,
				"license": [],
				"line_number": -1,
				"origin": "IBM"
			}
		],
		"model": "ibm/granite-8b-code-instruct"
	},
	"error": null
}
```
#### IBM Documentation Command
```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1g' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/ibm_doc_command.json | base64)"
```

##### Expected Response
```
{
    "request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1g",
    "response": {
        "augmented_prompt": "",
        "generated_response": "",
        "create_ts": "2024-12-10T07:37:04.500900",
        "message": {
            "role": "ASSISTANT",
            "content": "The syntax for creating a model definition with the specified payload in IBM Cloud Pak for Data is:\n```\n// Assisted by watsonx Code Assistant \ncpd-cli ml model-definition create \\\\\n[--command=<command-name>] \\\\\n[--context=<catalog-project-or-space-id>] \\\\\n[--cpd-config=<cpd-config-location>] \\\\\n[--cpd-scope=<cpd-scope>] \\\\\n[--custom=<map<key,value>>] \\\\\n[--description=<resource-description>] \\\\\n[--jmes-query=<jmespath-query>] \\\\\n--name=<resource-name> \\\\\n[--output=json|yaml|table] \\\\\n[--output-file=<output-file-location>] \\\\\n[--platform=<platform-object>] \\\\\n[--profile=<cpd-profile-name>] \\\\\n[--project-id=<cpd-project-id>] \\\\\n[--quiet] \\\\\n[--raw-output=true|false] \\\\\n[--space-id=<space-identifier>] \\\\\n[--tags=<tag1,tag2,...>] \\\\\n[--verbose]\n```\n .....",
            "type": "IBM_DOCS",
            "context": [
                "ml model-definition create Create a model definition with the specified payload. A model definition represents code that is used to train one or more models. Syntax cpd-cli ml model-definition create \\ [--command=<command-name>] \\ [--context=<catalog-project-or-space-id>] \\ [--cpd-config=<cpd-config-location>] \\ [--cpd-scope=<cpd-scope>] \\ [--custom=<map<key,value>>] \\ [--description=<resource-description>] \\ [--jmes-query=<jmespath-query>] \\ --name=<resource-name> \\ [--output=json|yaml|table] \\ [--output-file=<output-file-location>] \\ --platform=<platform-object> \\ --profile=<cpd-profile-name> \\ [--project-id=<cpd-project-id>] \\ [--quiet] \\ [--raw-output=true|false] \\ [--space-id=<space-identifier>] \\ [--tags=<tag1,tag2,...>] \\ [--verbose] Arguments The ml model-definition create command has no arguments ....."
            ],
            "use_for_context": true
        },
        "similarity_matches": [],
        "model": "ibm/granite-13b-chat-v2"
    },
    "error": null
}     
```    
                                                         
#### Chat Request with similarity detected in response

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1h' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/chat_with_similarity.json | base64)"
```

##### Expected Response

```
{
    "request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1c-test2files",
    "response": {
        "augmented_prompt": "",
        "generated_response": "",
        "create_ts": "2024-12-12T09:33:49.986149",
        "message": {
            "role": "ASSISTANT",
            "content": "The code suggestion that you requested is similar to code found in https://github.com/geekboxzone/lollipop_external_chromium_org/blob/geekbox/build/android/pylib/forwarder.py licensed under other. Code suggestions that are similar to code sources under this licence are blocked. Retry with a more specific request or ask your administrator for help.",
            "type": "CHAT",
            "context": "",
            "use_for_context": false
        },
        "similarity_matches": [
            {
                "action_status": "BLOCK",
                "title": "",
                "repo_name": "",
                "uri": "https://github.com/geekboxzone/lollipop_external_chromium_org/blob/geekbox/build/android/pylib/forwarder.py",
                "score": 0.9967351,
                "license": [
                    "other"
                ],
                "line_number": 196,
                "origin": "IBM"
            }
        ],
        "model": "ibm/granite-8b-code-instruct"
    },
    "error": {
        "code": "WCA-0103-E",
        "message": "The code suggestion that you requested is similar to code found in https://github.com/geekboxzone/lollipop_external_chromium_org/blob/geekbox/build/android/pylib/forwarder.py licensed under other. Code suggestions that are similar to code sources under this licence are blocked. Retry with a more specific request or ask your administrator for help."
    }
}
```

#### Chat Request with NPR(Non Programming Request) detected in response

```
curl --request POST \
  --url https://api.dataplatform.cloud.ibm.com/v2/wca/core/chat/text/generation \
  --header 'Authorization: Bearer <access_token>' \
  --header 'Request-ID: 9bdb1d8c-3a6b-428c-a9a0-204c5164ea1h' \
  --header 'content-type: multipart/form-data' \
  --form message="$(cat rest_api/chat_with_npr.json | base64)"
```

##### Expected Response
```
{
    "request_id": "9bdb1d8c-3a6b-428c-a9a0-204c5164ea1h",
    "response": {
        "augmented_prompt": "",
        "generated_response": "",
        "create_ts": "2024-12-11T12:19:41.135165",
        "message": {
            "role": "ASSISTANT",
            "content": "Hello! How can I assist you today?",
            "type": "CHAT",
            "context": "",
            "use_for_context": false
        },
        "similarity_matches": [],
        "model": "ibm/granite-8b-code-instruct"
    },
    "error": {
        "code": "WCA-0102-W",
        "message": "The request might not be about coding. Enter a code-related question for a better response."
    }
}
```
