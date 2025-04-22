import gleam/list

type Id =
  Int

type Record(a) =
  #(Id, a)

pub type Table(a) {
  Table(incrementer: Id, records: List(Record(a)))
}

pub fn new() {
  Table(1, [])
}

pub fn get(table: Table(a), id: Id) {
  table.records
  |> list.filter(fn(record) { record.0 == id })
  |> list.first()
}

pub fn get_by(table: Table(a), selector: fn(a) -> Bool) {
  table.records
  |> list.filter(fn(record) { selector(record.1) })
  |> list.first()
}

pub fn id(record: Record(a)) {
  record.0
}

pub fn value(record: Record(a)) {
  record.1
}

pub fn insert(table: Table(a), record: a) {
  let new_record = #(table.incrementer, record)

  #(Table(table.incrementer + 1, [new_record, ..table.records]), new_record)
}

pub fn update(table: Table(a), id: Id, record: a) {
  let new_record = #(id, record)

  let records =
    list.map(table.records, fn(existing_record) {
      case existing_record.0 == id {
        True -> new_record
        False -> existing_record
      }
    })

  Table(table.incrementer, records)
}

pub fn delete(table: Table(a), id: Id) {
  let records =
    list.filter(table.records, fn(existing_record) { existing_record.0 != id })

  Table(table.incrementer, records)
}
