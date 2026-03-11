require "csv"

PTH = "tmp/data/"
CLIENTS = PTH + "2025_clients.csv"
FULL = PTH + "2025_full.csv"

clients = []

CSV.foreach(FULL, headers: true) do |r|
  r["is_client"] = false
  r["id"] = r["id"].to_i
  clients << r
end

CSV.foreach(CLIENTS, headers: true) do |r|
  id = r["id"].to_i
  client = clients.filter { |c| c["id"] == id }.first
  client["is_client"] = true
end

final = []

clients.each do |c|
  if c["is_client"]
    c["dependents"] = []
    final << c
  else
    final.last["dependents"] << c
  end
end

def change(cl)
  cols = [ "infant", "toddler", "child", "adult", "senior" ]

  name = cl["Name of Client"].split(" ")
  cl["first_name"] = name.first
  cl["last_name"] = name[1..-1].join(" ")
  cl.delete("Name of Client")
  cl.delete("id")
  cl.delete("is_client")
  cl.delete("Total household size")

  cl["member_counts"] = {}
  cols.each do |col|
    cl["member_counts"][col] = cl[col].present? ? cl[col].to_i : 0
    cl.delete(col)
  end

  cl["household_members"] = []

  cl["dependents"].each do |d|
    name = d["Name of Client"].split(" ")
    d["first_name"] = name.first
    d["last_name"] = name[1..-1].join(" ")
    d.delete("Name of Client")
    d.delete("address")
    d.delete("id")
    d.delete("Total household size")
    d.delete("mobile_number")
    d.delete("is_client")
    cols.each do |cc|
      d.delete(cc)
    end

    cl["household_members"] << HouseholdMember.new(d)
  end
  cl.delete("dependents")

  cl["uuid"] = SecureRandom.uuid

  Client.new cl
end

final = final.map { |c| change(c) }

Client.import final
