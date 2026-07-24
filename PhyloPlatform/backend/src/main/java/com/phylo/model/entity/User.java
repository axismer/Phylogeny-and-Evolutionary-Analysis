package com.phylo.model.entity;

import jakarta.persistence.*;

/**
 * 用户实体类
 */
@Entity
@Table(name = "user")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer uid;

    @Column(nullable = false, unique = true, length = 50)
    private String uname;

    @Column(nullable = false, length = 255)
    private String upassword;

    @Column(length = 50)
    private String nickname;

    @Column(length = 10)
    private String role;

    @Column(length = 100)
    private String email;

    public User() {}

    public User(String uname, String upassword, String nickname, String role, String email) {
        this.uname = uname;
        this.upassword = upassword;
        this.nickname = nickname;
        this.role = role;
        this.email = email;
    }

    public Integer getUid() { return uid; }
    public void setUid(Integer uid) { this.uid = uid; }
    public String getUname() { return uname; }
    public void setUname(String uname) { this.uname = uname; }
    public String getUpassword() { return upassword; }
    public void setUpassword(String upassword) { this.upassword = upassword; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
}
