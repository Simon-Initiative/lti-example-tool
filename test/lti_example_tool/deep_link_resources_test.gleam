import gleeunit/should
import lti_example_tool/deep_link_resources

pub fn parse_known_resource_ids_test() {
  deep_link_resources.parse("resource-1")
  |> should.equal(Ok(deep_link_resources.Resource1))

  deep_link_resources.parse("resource-2")
  |> should.equal(Ok(deep_link_resources.Resource2))

  deep_link_resources.parse("resource-3")
  |> should.equal(Ok(deep_link_resources.Resource3))
}

pub fn parse_invalid_resource_id_test() {
  deep_link_resources.parse("resource-9")
  |> should.equal(Error("Invalid resource id"))
}

pub fn resource_title_fallback_test() {
  deep_link_resources.from_custom_resource_id("resource-2")
  |> should.equal("Resource 2")

  deep_link_resources.from_custom_resource_id("custom-id")
  |> should.equal("custom-id")
}
