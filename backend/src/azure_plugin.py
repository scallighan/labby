import os
from typing import Annotated
from semantic_kernel.functions.kernel_function_decorator import kernel_function


from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.costmanagement import CostManagementClient

subscription_id = os.environ.get("AZURE_SUBSCRIPTION_ID")
class AzurePlugin:
    """A plugin to interact with Azure resources"""

    @kernel_function(description="list all Azure resource groups")
    def list_resource_groups(self) -> Annotated[str, "Returns the list of Azure resource groups"]:       
        print("System> I am listing all the Azure resource groups")
        token_credential = DefaultAzureCredential()
        resource_client = ResourceManagementClient(token_credential, subscription_id)
        resource_group_list = resource_client.resource_groups.list()
        list_list = list(resource_group_list)
        print(f"System> I found {len(list_list)} resource groups")
        str_arr = []
        for resource_group in list_list:
            str_arr.append(resource_group.name)
        print(f"System> {str_arr}")
        return "\n".join(str_arr)
    
    @kernel_function(description="list all Azure resources in a resource group")
    def list_by_resource_group(self, resource_group: Annotated[str, "The name of the Azure resource group"]) -> Annotated[str, "Returns the list of Azure resources in the resource group"]:
        print(f"System> I am listing all the Azure resources in the resource group: {resource_group}")
        token_credential = DefaultAzureCredential()
        resource_client = ResourceManagementClient(token_credential, subscription_id)
        resource_list = resource_client.resources.list_by_resource_group(
            resource_group, expand = "createdTime,changedTime")
        list_list = list(resource_list)
        print(f"System> I found {len(list_list)} resources in the resource group {resource_group}")
        str_arr = []
        for resource in list_list:
            r_dict = {
                "name": resource.name,
                "type": resource.type.split("/")[1],
            }
            str_arr.append(f"{r_dict}")
        print(f"System> {str_arr}")
        return "\n".join(str_arr)

    @kernel_function(description="look up an Azure resource by tag")
    def get_resource_by_tag(
        self, 
        key: Annotated[str, "The key of the tag of the Azure resource"], 
        value: Annotated[str, "The value of the tag of the Azure resource"]
    ) -> Annotated[str, "Returns the list of Azure resources with the tag"]:
        print(f"System> I am looking up the Azure resources with the tag: {key}: {value}")
        token_credential = DefaultAzureCredential()
        resource_client = ResourceManagementClient(token_credential, subscription_id)
        resource_list = resource_client.resources.list(filter=f"tagName eq '{key}' and tagValue eq '{value}'")
        #resource_list = resource_client.resources.list_by_resource_group(
        #    "rg-quackersbank-central", expand = "createdTime,changedTime")
        list_list = list(resource_list)
        print(f"System> I found {len(list_list)} resources with the tagName {key} and tagValue {value}")        
        str_arr = []
        for resource in list_list:
            #print(f"System> {resource}")
            r_dict = {
                "name": resource.name,
                "type": resource.type.split("/")[1],
            }
            str_arr.append(f"{r_dict}")
        print(f"System> {str_arr}")
        return "\n".join(str_arr)
    
    @kernel_function(description="look up an Azure resource by name")
    def get_resource_by_name(
        self, 
        name: Annotated[str, "The name of the Azure resource"]
    ) -> Annotated[str, "Returns the Azure resource with the name"]:
        print(f"System> I am looking up the Azure resource with the name: {name}")
        token_credential = DefaultAzureCredential()
        resource_client = ResourceManagementClient(token_credential, subscription_id)
        resource_list = resource_client.resources.list(filter=f"name eq '{name}'")
        list_list = list(resource_list)
        print(f"System> I found the resource {name}: {list_list}")
        str_arr = []
        for resource in list_list:
            r_dict = {
                "name": resource.name,
                "type": resource.type.split("/")[1],
                "id": resource.id
            }
            str_arr.append(f"{r_dict}")
        print(f"System> {str_arr}")
        return "\n".join(str_arr)
    
    @kernel_function(description="look up an Azure resource by type")
    def get_resource_by_type(
        self,
        type: Annotated[str, "The type of the Azure resource"]
    ) -> Annotated[str, "Returns the list of Azure resources with the type"]:
        print(f"System> I am looking up the Azure resources with the type: {type}")
        token_credential = DefaultAzureCredential()
        resource_client = ResourceManagementClient(token_credential, subscription_id)
        resource_list = resource_client.resources.list(filter=f"resourceType eq '{type}'")
        list_list = list(resource_list)
        print(f"System> I found {len(list_list)} resources with the type {type}")
        str_arr = []
        for resource in list_list:
            r_dict = {
                "name": resource.name,
                "type": resource.type.split("/")[1],
            }
            str_arr.append(f"{r_dict}")
        print(f"System> {str_arr}")
        return "\n".join(str_arr)
    
    @kernel_function(description="find the cost views of an Azure resource scope")
    def get_cost_by_scope(self, scope: Annotated[str, "The scope of the Azure resource"]) -> Annotated[str, "Returns the cost views of the Azure resource scope"]:
        print(f"System> I am looking up the cost of the Azure resource scope: {scope}")
        token_credential = DefaultAzureCredential()
        cost_client = CostManagementClient(token_credential)
        parameters = {
            "dataset": {
                "aggregation": {"totalCost": {"function": "Sum", "name": "PreTaxCost"}},
                "granularity": "Daily",
                "grouping": [{"name": "ResourceType", "type": "Dimension"}],
            },
            "timeframe": "MonthToDate",
            "type": "Usage",
        }
        usage = cost_client.query.usage(scope, parameters=parameters)
        print(usage)
        md_table = "| "
        for column in usage.columns:
            md_table += f"{column.name} | "
        md_table += "\n| "
        for column in usage.columns:
            md_table += f" --- | "
        
        for row in usage.rows:
            md_table += "\n| "
            for value in row:
                md_table += f"{value} | "
        md_table += "\n"
        return md_table
