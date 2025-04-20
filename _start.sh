start=$(date +%s)

vagrant up | tee log.txt
vagrant plugin install vagrant-hostmanager
vagrant hostmanager

end=$(date +%s)

# Default to 0 if start or end is empty
start=${start:-0}
end=${end:-0}

# Now safe to do math
runtime=$((end - start))
echo "Time taken to complete: $runtime seconds"

