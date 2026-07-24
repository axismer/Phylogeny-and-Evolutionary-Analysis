package com.phylo.repository;

import com.phylo.model.entity.Species;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SpeciesRepository extends JpaRepository<Species, Integer> {
    List<Species> findByUid(Integer uid);
    List<Species> findBySnameContaining(String sname);
}
