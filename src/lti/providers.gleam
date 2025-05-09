import lti/providers/data_provider.{type DataProvider}
import lti/providers/http_provider.{type HttpProvider}

pub type Providers {
  Providers(data: DataProvider, http: HttpProvider)
}
