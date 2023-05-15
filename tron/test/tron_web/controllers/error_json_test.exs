defmodule TronWeb.ErrorJSONTest do
  use TronWeb.ConnCase, async: true

  test "renders 404" do
    assert TronWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert TronWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
