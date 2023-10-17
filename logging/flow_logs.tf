# Copyright (c) 2023 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {

  flow_logs_target_types = ["VCN","SUBNET","VNIC"]

  flow_logs_compartment_ids = flatten([
    for fl_key, fl_value in (var.logging_configuration.flow_logs != null ? var.logging_configuration.flow_logs : {}) : [
      for cmp_id in fl_value.target_compartment_ids : [cmp_id]
    ]
  ]) 

  subnets_flow_logs = flatten([
    for fl_key, fl_value in (var.logging_configuration.flow_logs != null ? var.logging_configuration.flow_logs : {}) : [
      for cmp_id in fl_value.target_compartment_ids : [
        for subnet in data.oci_core_subnets.these[cmp_id].subnets : {
          key = upper("${fl_key}-${subnet.display_name}-${substr(subnet.id,-10,-1)}")
          category = "subnet"
          resource_id = subnet.id
          service = "flowlogs"
          name = "${subnet.display_name}-${substr(subnet.id,-10,-1)}-flow-log"
          log_group_id = fl_value.log_group_id
          is_enabled = fl_value.is_enabled
          retention_duration = fl_value.retention_duration
          defined_tags = fl_value.defined_tags
          freeform_tags = fl_value.freeform_tags
          target_resource_type = fl_value.target_resource_type
        }  
      ]
    ] if upper(fl_value.target_resource_type) == "SUBNET"
  ])  

  vcns_flow_logs = flatten([
    for fl_key, fl_value in (var.logging_configuration.flow_logs != null ? var.logging_configuration.flow_logs : {}) : [
      for cmp_id in fl_value.target_compartment_ids : [
        for vcn in data.oci_core_vcns.these[cmp_id].virtual_networks : {
          key = upper("${fl_key}-${vcn.display_name}-${substr(vcn.id,-10,-1)}")
          category = "vcn"
          resource_id = vcn.id
          service = "flowlogs"
          name = "${vcn.display_name}-${substr(vcn.id,-10,-1)}-flow-log"
          log_group_id = fl_value.log_group_id
          is_enabled = fl_value.is_enabled
          retention_duration = fl_value.retention_duration
          defined_tags = fl_value.defined_tags
          freeform_tags = fl_value.freeform_tags
          target_resource_type = fl_value.target_resource_type
        }  
      ]
    ] if upper(fl_value.target_resource_type) == "VCN"
  ]) 

  vnics_flow_logs = flatten([
    for fl_key, fl_value in (var.logging_configuration.flow_logs != null ? var.logging_configuration.flow_logs : {}) : [
      for cmp_id in fl_value.target_compartment_ids : [
        for attach in data.oci_core_vnic_attachments.these[cmp_id].vnic_attachments : {
          key = upper("${fl_key}-${data.oci_core_vnic.these[attach.vnic_id].display_name}")
          category = "vnic"
          resource_id = attach.vnic_id
          service = "flowlogs"
          name = "${data.oci_core_vnic.these[attach.vnic_id].display_name}-flow-log"
          log_group_id = fl_value.log_group_id
          is_enabled = fl_value.is_enabled
          retention_duration = fl_value.retention_duration
          defined_tags = fl_value.defined_tags
          freeform_tags = fl_value.freeform_tags
          target_resource_type = fl_value.target_resource_type
        }  
      ]
    ] if upper(fl_value.target_resource_type) == "VNIC"
  ]) 

  vnics_ids = flatten([
      for fl_key, fl_value in (var.logging_configuration.flow_logs != null ? var.logging_configuration.flow_logs : {}) : [
        for cmp_id in fl_value.target_compartment_ids : [
          for attach in data.oci_core_vnic_attachments.these[cmp_id].vnic_attachments : [attach.vnic_id]
        ] 
      ] 
  ])   

  nlbs_flow_logs = flatten([
    for fl_key, fl_value in (var.logging_configuration.flow_logs != null ? var.logging_configuration.flow_logs : {}) : [
      for k, v in data.oci_core_private_ips.nlbs : [
        for ip in v.private_ips : {
          key = upper("${fl_key}-${ip.display_name}")
          category = "vnic"
          resource_id = ip.vnic_id
          service = "flowlogs"
          name = "${ip.display_name}-flow-log"
          log_group_id = fl_value.log_group_id
          is_enabled = fl_value.is_enabled
          retention_duration = fl_value.retention_duration
          defined_tags = fl_value.defined_tags
          freeform_tags = fl_value.freeform_tags
          target_resource_type = fl_value.target_resource_type
        }  
      ] 
    ] if upper(fl_value.target_resource_type) == "VNIC"
  ])

  nlbs_info = flatten([
    for k,v in data.oci_network_load_balancer_network_load_balancers.these : [
      for col_elem in v.network_load_balancer_collection : [
        for nlb in col_elem.items : [
          for i in nlb.ip_addresses : 
            {"ip_address" : i.ip_address, "subnet_id": nlb.subnet_id}
        ]
      ]
    ]
  ])
} 

data "oci_core_subnets" "these" {
  for_each = toset(local.flow_logs_compartment_ids)
    compartment_id = each.key
}

data "oci_core_vcns" "these" {
  for_each = toset(local.flow_logs_compartment_ids)
    compartment_id = each.key
}

data "oci_core_vnic_attachments" "these" {
  for_each = toset(local.flow_logs_compartment_ids)
    compartment_id = each.key
}

data "oci_core_vnic" "these" {
  for_each = toset(local.vnics_ids)
    vnic_id = each.key
}

data "oci_network_load_balancer_network_load_balancers" "these" {
  for_each = toset(local.flow_logs_compartment_ids)
    compartment_id = each.key
}

data "oci_core_private_ips" "nlbs" {
  for_each = {for v in local.nlbs_info : v.ip_address => v.subnet_id}
    ip_address = each.key
    subnet_id = each.value
}

resource "oci_logging_log" "flow_logs" {
  for_each = { for v in concat(local.subnets_flow_logs, local.vcns_flow_logs, local.vnics_flow_logs, local.nlbs_flow_logs) : v.key => {
                category = v.category
                resource_id = v.resource_id
                service = v.service
                name = v.name
                log_group_id = v.log_group_id
                is_enabled = v.is_enabled
                retention_duration = v.retention_duration
                defined_tags = v.defined_tags
                freeform_tags = v.freeform_tags
                target_resource_type = v.target_resource_type }}
    lifecycle {
      precondition {
        condition = contains(local.flow_logs_target_types, upper(each.value.target_resource_type))
        error_message = "VALIDATION FAILURE: \"${each.value.target_resource_type}\" value is invalid for \"target_resource_type\" attribute. Valid values are: ${join(",",local.flow_logs_target_types)} (case insensitive)."
      }
    }
    display_name = each.value.name
    log_group_id = oci_logging_log_group.these[each.value.log_group_id].id
    log_type     = "SERVICE"
    configuration {
      #compartment_id = each.value.compartment_id
      source {
        category    = each.value.category
        resource    = each.value.resource_id
        service     = each.value.service
        source_type = "OCISERVICE"
      }
    }
    is_enabled         = coalesce(each.value.is_enabled,true) 
    retention_duration = coalesce(each.value.retention_duration, 60)
    defined_tags       = each.value.defined_tags != null ? each.value.defined_tags : var.logging_configuration.default_defined_tags
    freeform_tags = merge(local.cislz_module_tag, each.value.freeform_tags != null ? each.value.freeform_tags : var.logging_configuration.default_freeform_tags)
}