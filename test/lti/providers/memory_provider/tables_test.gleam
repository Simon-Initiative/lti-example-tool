import gleeunit/should
import lti/providers/memory_provider/tables

pub fn new_test() {
  let table = tables.new()
  table
  |> should.equal(tables.Table(1, []))
}

pub fn insert_test() {
  let table = tables.new()
  let #(table, _) = tables.insert(table, "record1")
  let #(table, _) = tables.insert(table, "record2")

  table
  |> should.equal(tables.Table(3, [#(2, "record2"), #(1, "record1")]))
}

pub fn get_test() {
  let table = tables.new()
  let #(table, _) = tables.insert(table, "record1")
  let #(table, _) = tables.insert(table, "record2")

  let result = tables.get(table, 1)
  result
  |> should.equal(Ok(#(1, "record1")))

  let missing = tables.get(table, 3)
  missing
  |> should.equal(Error(Nil))
}

pub fn update_test() {
  let table = tables.new()
  let #(table, _) = tables.insert(table, "record1")
  let #(table, _) = tables.insert(table, "record2")

  let updated_table = tables.update(table, 1, "updated_record1")
  updated_table
  |> should.equal(tables.Table(3, [#(2, "record2"), #(1, "updated_record1")]))
}

pub fn delete_test() {
  let table = tables.new()
  let #(table, _) = tables.insert(table, "record1")
  let #(table, _) = tables.insert(table, "record2")

  let updated_table = tables.delete(table, 1)
  updated_table
  |> should.equal(tables.Table(3, [#(2, "record2")]))
}
