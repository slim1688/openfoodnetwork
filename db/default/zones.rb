unless Spree::Zone.find_by(name: "EU_VAT")
  eu_vat = Spree::Zone.create!(name: "EU_VAT", description: "Countries that make up the EU VAT zone.")

  ["Poland", "Finland", "Portugal", "Romania", "Germany", "France",
   "Slovakia", "Hungary", "Slovenia", "Ireland", "Austria", "Spain",
   "Italy", "Belgium", "Sweden", "Latvia", "Bulgaria", "United Kingdom",
   "Lithuania", "Cyprus", "Luxembourg", "Malta", "Denmark", "Netherlands",
   "Estonia"].each do |name|
    eu_vat.zone_members.create!(zoneable: Spree::Country.find_by!(name: name))
  end
end

unless Spree::Zone.find_by(name: "North America")
  north_america = Spree::Zone.create!(name: "North America", description: "USA + Canada")

  ["United States", "Canada"].each do |name|
    north_america.zone_members.create!(zoneable: Spree::Country.find_by!(name: name))
  end
end
